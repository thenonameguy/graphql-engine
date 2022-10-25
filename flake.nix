{
  # This is a template created by `hix init`
  inputs.haskellNix.url = "github:thenonameguy/haskell.nix/no-ubxt-patch";
  inputs.nixpkgs.follows = "haskellNix/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils, haskellNix }:
    let
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        overlays = [
          haskellNix.overlay
          (final: prev: {
            graphql-engine =
              final.haskell-nix.hix.project {
                src = final.pkgs.haskell-nix.cleanSourceHaskell {
                  src = ./.;
                  name = "graphql-engine-src";
                };
                evalSystem = "x86_64-linux";

                modules = [
                  {
                    packages.mysql.components.library.libs = pkgs.lib.mkForce [ pkgs.libmysqlclient.dev ];
                  }
                ];
              };
          })
        ];
        pkgs = import nixpkgs { inherit system overlays; inherit (haskellNix) config; };
        flake = pkgs.graphql-engine.flake { };
        # Non-Haskell shell tools go here
        shell.buildInputs = with pkgs; [
          nixpkgs-fmt
        ];
      in
      flake // {
        packages.default = flake.packages."graphql-engine:exe:graphql-engine";
      });

  # --- Flake Local Nix Configuration ----------------------------
  nixConfig = {
    # This sets the flake to use the IOG nix cache.
    # Nix should ask for permission before using it,
    # but remove it here if you do not want it to.
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
    allow-import-from-derivation = "true";
  };
}
