{
  # This is a template created by `hix init`
  inputs.haskellNix.url = "github:input-output-hk/haskell.nix";
  inputs.nixpkgs.follows = "haskellNix/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils, haskellNix }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        overlays = [
          haskellNix.overlay
          (final: prev: {
            graphql-engine =
              final.haskell-nix.hix.project {
                src = ./.;
		compiler-nix-name = "ghc924";
                evalSystem = system;
                index-state = "2022-10-25T00:00:00Z";

                # taking notes from https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-unstable/pkgs/development/haskell-modules/hackage-packages.nix
                modules = [
                  {
                    packages.mysql.components.library.libs = pkgs.lib.mkForce [ pkgs.libmysqlclient.dev ];
                    packages.mysql-simple.components.library.libs = [pkgs.openssl pkgs.zlib];
                    # TODO: add pg_dump to PATH
                    packages.graphql-engine.components.library.libs = [pkgs.openssl pkgs.zlib];
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
        packages.default = flake.packages."$system"."graphql-engine:exe:graphql-engine";
      });

  # --- Flake Local Nix Configuration ----------------------------
  nixConfig = {
    # This sets the flake to use the IOG nix cache.
    # Nix should ask for permission before using it,
    # but remove it here if you do not want it to.
    extra-substituters = [ "https://cache.iog.io" "https://cache.zw3rk.com" ];
    extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk=" ];
    allow-import-from-derivation = "true";
  };
}
