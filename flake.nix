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
        overlays = [ haskellNix.overlay ];
        pkgs = import nixpkgs { inherit system overlays; inherit (haskellNix) config; };
        materializedPath = ./. + "/nix/materialized/${system}";
            project = pkgs.haskell-nix.cabalProject {
                src = ./.;
                index-state = "2022-09-13T01:09:29Z";
                materialized = if builtins.pathExists materializedPath then materializedPath else null;
                compiler-nix-name = "ghc924";
		shell.tools = {
		  cabal = {};
		  haskell-language-server = {};
		  hlint = {};
		};

        # Non-Haskell shell tools go here
        shell.buildInputs = with pkgs; [
          nixpkgs-fmt
        ];
                # taking notes from https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-unstable/pkgs/development/haskell-modules/hackage-packages.nix
                modules = [
                  {
                    packages.mysql.components.library.libs = pkgs.lib.mkForce [ pkgs.libmysqlclient.dev ];
                    packages.mysql-simple.components.library.libs = [ pkgs.openssl pkgs.zlib ];
                    # TODO: add pg_dump to PATH
                    packages.graphql-engine.components.library.libs = [ pkgs.openssl pkgs.zlib ];
                  }
                ];
              };
        flake = project.flake { };
      in
      # flake //
      {
        packages = flake.packages // {
          inherit (project.plan-nix.passthru) generateMaterialized;
          default = flake.packages."graphql-engine:exe:graphql-engine";
        };
        apps = flake.apps // {
          updateAllMaterialized = {
            type = "app";
            program = (pkgs.writeShellScript "updateAllMaterialized" ''
              set -eEuo pipefail
              export PATH="${pkgs.lib.makeBinPath [ pkgs.nix pkgs.jq pkgs.coreutils pkgs.git ]}"
              export NIX_CONFIG="
                allow-import-from-derivation = true
                experimental-features = flakes nix-command
              "
              ${builtins.concatStringsSep "\n" (map (system: ''
                script="$(nix build .#packages.${system}.generateMaterialized --json | jq -r '.[0].outputs.out')"
                echo "Running $script on ./nix/materialized/${system}" >&2
                "$script" "./nix/materialized/${system}"
              '') supportedSystems)}
            '').outPath;
          };
        };} );

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
