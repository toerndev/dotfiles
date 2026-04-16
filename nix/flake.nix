{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    claude-code.url = "github:sadjow/claude-code-nix";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, claude-code, home-manager, deploy-rs, sops-nix, ... }@inputs:
    {
      nixosConfigurations = {
        htpc = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/htpc
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.losipai = import ./home/default.nix;
              home-manager.users.htpc-user = import ./home/htpc.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
          specialArgs = { inherit inputs; };
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
