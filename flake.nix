{
  description = "Everscending darwin system";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Claude Code from its own flake instead of the Homebrew cask: releases land
    # within the hour and the binary is self-contained. Deliberately NOT following
    # our nixpkgs - overriding it changes the derivation hash, which misses the
    # project's Cachix cache, and upstream only tests against its own pin.
    claude-code-nix.url = "github:sadjow/claude-code-nix";

    # Codex CLI, from the same maintainer and for the same reasons as above,
    # including not following our nixpkgs.
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs
    , claude-code-nix, codex-cli-nix }:
    let
      # The one username line to change if this isn't your machine.
      # bootstrap.sh offers to rewrite this for you if your macOS username differs.
      user = "jordanphillips";
    in
  {  

    darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit user; };
      modules = [ 
        ./configuration.nix 
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user inputs; };
            home-manager.users.${user} = import ./home.nix;
          } 
      ];
    };
  };
}

