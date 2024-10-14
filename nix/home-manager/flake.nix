{
  inputs = {
    home-manager.url = "github:rycee/home-manager";
  };

  outputs = { self, home-manager, ... }: {
    homeConfigurations = {
      martint = home-manager.lib.homeManagerConfiguration {
        pkgs = import <nixpkgs> {};
	modules = [
	  ./home.nix
	];
      };
    };
  };
}
