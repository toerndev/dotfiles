{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, deploy-rs, ... }@inputs:
    let
      pkgs-unstable = import nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations = {
        htpc = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/htpc
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.losipai = import ./home/default.nix;
              home-manager.users.htpc-user = import ./home/htpc.nix;
              home-manager.extraSpecialArgs = { inherit inputs pkgs-unstable; };
            }
          ];
          specialArgs = { inherit inputs pkgs-unstable; };
        };
      };

      deploy.nodes.htpc = {
        hostname = "10.100.0.1";
        profiles.system = {
          user = "root";
          sshUser = "losipai";
          path = deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.htpc;
        };
      };

      checks.x86_64-linux =
        deploy-rs.lib.x86_64-linux.deployChecks self.deploy;
    };
}
