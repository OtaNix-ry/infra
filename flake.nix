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
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
        devenv-test = self.devShells.${system}.default.config.test;

        azure-image =
          (nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./image/configuration.nix
            ];
          }).config.system.build.azureImage;
      });

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
