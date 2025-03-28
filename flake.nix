{
  description = "A Nix flake for creating an R development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};

      # Define general development packages
      packages = with pkgs; [
        R
        radianWrapper
      ];

      # Define R packages using rPackages overlay
      rPackages = with pkgs.rPackages; [
        tidyverse
        janitor
        here
        languageserver
        emmeans
        lme4
        lmerTest
      ];

      # Combine all package lists, including the Python environment itself
      allPackages = packages ++ rPackages;
    in {
      devShell = pkgs.mkShell {
        buildInputs = allPackages; # Use allPackages as input to the development shell
        shellHook = ''
          # R environment setup
          export R_LIBS_USER=$PWD/R/Library; # Set R user library path to project directory
          mkdir -p "$R_LIBS_USER"; # Create the R user library directory if it doesn't exist
        '';
      };
    });
}
