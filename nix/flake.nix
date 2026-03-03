{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      systemConfig = {
        stateVersion = "24.11";
	architecture = "x86_64-linux";
      };
      pkgs = import nixpkgs {
        system = systemConfig.architecture;
      };
    in {
      nixosConfigurations = {
        htpc = nixpkgs.lib.nixosSystem {
	  system = systemConfig.architecture;
	  modules = [
	    ./htpc.nix
	    ./common.nix
	    home-manager.nixosModules.home-manager
	    {
	      users.users.losipai = {
		isNormalUser = true;
		extraGroups = [ "input" "audio" "pipewire" "networkmanager" "wheel" ];
		packages = with pkgs; [];
	      };

              nixpkgs.config.allowUnfree = true;
	      home-manager.useGlobalPkgs = true;
	      home-manager.useUserPackages = true;
	      home-manager.backupFileExtension = "backup";
	      home-manager.users.losipai = import ./home/default.nix;
	      home-manager.users.htpc-user = import ./home/htpc.nix;
	      home-manager.extraSpecialArgs = { inherit inputs systemConfig; };
	    }
	  ];
	  specialArgs = { inherit inputs systemConfig; };
	};
      };

      homeConfigurations = {
        "losipai" = home-manager.lib.homeManagerConfiguration {
	  pkgs = nixpkgs.legacyPackages.${systemConfig.architecture};
	  extraSpecialArgs = { inherit inputs systemConfig; };
	  modules = [
	    ./home/default.nix
	  ];
	};
      };
    };
}
