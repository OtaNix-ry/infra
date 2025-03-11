{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      systems,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (nixpkgs) lib;
        in
        {
          devenv-up = self.devShells.${system}.default.config.procfileScript;
          devenv-test = self.devShells.${system}.default.config.test;

          upload-image =
            let
              az = lib.getExe pkgs.azure-cli;
              azcopy = lib.getExe pkgs.azure-storage-azcopy;
              jq = lib.getExe pkgs.jq;
            in
            pkgs.writeShellScriptBin "otanix-upload-image" ''
              set -euo pipefail

              group=''${group:-vm-img-rg}
              location=''${location:-northeurope}
              img_name=''${img_name:-nixos-image}
              img_file=''${img_file:-$(nix build .#azure-image --no-link --print-out-paths | xargs readlink -f)/disk.vhd}

              outPathDefault=
              if [[ "$img_file" == /nix/store/*/disk.vhd ]] ; then
                outPathDefault=''${img_file%/disk.vhd}
              fi
              outPath=''${outPath:-$outPathDefault}

              oldResources=$(${az} resource list)
              oldDiskId=$(${jq} --raw-output '.[] | select(.name=="nixos-image" and .type == "Microsoft.Compute/disks") | .id' <<< "$oldResources")
              oldOutPath=$(${jq} --raw-output '.[] | select(.name=="nixos-image" and .type == "Microsoft.Compute/disks") | .tags.outPath' <<< "$oldResources")

              set -x

              cleanDefault=
              if [[ "$outPath" != "$oldOutPath" ]] ; then
                cleanDefault=1
              fi
              if [[ -z "$oldDiskId" ]] ; then
                # If the empty, there's probably no disk, and nothing to clean?
                cleanDefault=
              fi
              clean=''${clean:-$cleanDefault}


              if ! ${az} group show -n "$group" &>/dev/null; then
                ${az} group create --name "$group" --location "$location"
              fi

              if [[ -n "$clean" ]]; then
                ${az} image delete -g "$group" -n "$img_name"
                ${az} disk delete -g "$group" -n "$img_name" --yes
              fi

              if ! ${az} disk show -g "$group" -n "$img_name" &>/dev/null; then
                bytes="$(stat -c %s "$img_file")"
                timeout=''${timeout:-$(( 60 * 60 ))} # disk access token timeout
                ${az} disk create \
                  --resource-group "$group" \
                  --name "$img_name" \
                  --hyper-v-generation V2 \
                  --sku Premium_LRS \
                  --tags outPath="$outPath" \
                  --for-upload true --upload-size-bytes "$bytes"
                sasurl="$(
                  ${az} disk grant-access \
                    --access-level Write \
                    --resource-group "$group" \
                    --name "$img_name" \
                    --duration-in-seconds "$timeout" \
                      | ${jq} -r '.accessSas'
                )"
                ${azcopy} copy "$img_file" "$sasurl" \
                  --blob-type PageBlob

                ${az} disk revoke-access \
                  --resource-group "$group" \
                  --name "$img_name"
              fi

              if ! ${az} image show -g "$group" -n "$img_name" &>/dev/null; then
                diskid="$(${az} disk show -g "$group" -n "$img_name" -o json | ${jq} -r .id)"

                ${az} image create \
                  --resource-group "$group" \
                  --name "$img_name" \
                  --source "$diskid" \
                  --storage-sku Premium_LRS \
                  --hyper-v-generation V2 \
                  --tags outPath="$outPath" \
                  --os-type "linux" >/dev/null
              fi

              imageid="$(${az} image show -g "$group" -n "$img_name" -o json | ${jq} -r .id)"
              echo "$imageid"
            '';

          azure-image =
            (nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                ./image/configuration.nix
              ];
            }).config.system.build.azureImage;
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              {
                # https://devenv.sh/reference/options/
                packages = [
                  pkgs.azure-cli
                  pkgs.opentofu
                ];
                languages.terraform.enable = true;
                languages.terraform.package = pkgs.opentofu;

                git-hooks.hooks.terraform-fmt = {
                  enable = true;
                  name = "Terraform fmt check";
                  entry = "tofu fmt --recursive";
                  pass_filenames = false;
                };
              }
            ];
          };
        }
      );
    };
}
