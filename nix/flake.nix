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

  # One flake, one flake.lock, one nixosConfiguration per machine. Each
  # hosts/<name>/default.nix picks its modules; losipai's home-manager config
  # is the same on every host.
  #
  # The hosts share the lock, and Nix only builds what a host uses: a bump that
  # builds for one host can still break the other. `nix flake check` builds
  # every host (see `checks`); run it after any lock bump or shared-module
  # change, before deploying either.
  outputs = { self, nixpkgs, home-manager, deploy-rs, ... }@inputs:
    let
      lib = nixpkgs.lib;

      mkHost = { name, homeUsers ? { } }: lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/${name}
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users = { losipai = import ./home/default.nix; } // homeUsers;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };

      deployNode = { name, hostname, sshOpts ? [ ] }: {
        inherit hostname sshOpts;
        profiles.system = {
          user = "root";
          sshUser = "losipai";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${name};
        };
      };
    in
    {
      nixosConfigurations = {
        server = mkHost { name = "server"; };
        # Minimal first install of the server: SSH on the LAN, no WireGuard or sops.
        server-bootstrap = mkHost { name = "server-bootstrap"; };
        htpc = mkHost {
          name = "htpc";
          homeUsers.htpc-user = import ./home/htpc.nix;
        };
      };

      deploy.nodes = {
        server = deployNode { name = "server"; hostname = "10.100.0.1"; };

        # Through the server: the htpc has no WireGuard.
        htpc = deployNode {
          name = "htpc";
          hostname = "192.168.1.71";
          sshOpts = [ "-J" "losipai@10.100.0.1" ];
        };
      };

      checks.x86_64-linux =
        deploy-rs.lib.x86_64-linux.deployChecks self.deploy
        // lib.mapAttrs' (name: host: lib.nameValuePair "host-${name}" host.config.system.build.toplevel)
          self.nixosConfigurations;
    };
}
