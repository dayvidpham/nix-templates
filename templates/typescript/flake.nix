{
  description = "Reproducible TypeScript/Node.js dev environment";

  # ============================================================
  # INPUTS
  # ============================================================

  inputs = rec {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs = nixpkgs-stable;
    flake-utils.url = "github:numtide/flake-utils";
  };

  # ============================================================
  # OUTPUTS
  # ============================================================

  outputs =
    inputs@{ self
    , nixpkgs
    , nixpkgs-stable
    , nixpkgs-unstable
    , flake-utils
    , ...
    }:
    let
      mkEnvFromChannel = (nixpkgs-channel:
        flake-utils.lib.eachDefaultSystem (system:
          let
            # ----------------------------------------------------------
            # Package Set Configuration
            # ----------------------------------------------------------

            pkgs = import nixpkgs-channel {
              inherit system;
              config.allowUnfree = true;
            };

            # ----------------------------------------------------------
            # Node.js / TypeScript Configuration
            # ----------------------------------------------------------

            nodePkgs = pkgs.nodejs_24.pkgs; # Reserved for npm global packages

            # ----------------------------------------------------------
            # Development Shell
            # ----------------------------------------------------------

            devShell = pkgs.mkShell {
              name = "typescript-dev"; # <-- Rename to your project

              packages = [
                # Runtime
                pkgs.nodejs_24
                pkgs.bun
                pkgs.pnpm

                # TypeScript tooling
                pkgs.nodePackages.typescript-language-server
                pkgs.nodePackages.typescript
              ];

              shellHook = ''
                # Add bun global binaries to PATH
                export PATH="$HOME/.bun/bin:$PATH"
              '';

              allowSubstitutes = false;
            };

            # ----------------------------------------------------------
            # FHS Environment
            # For packages requiring traditional Linux filesystem layout
            # (e.g., native Node addons, electron builds)
            # ----------------------------------------------------------

            fhsEnv = (pkgs.buildFHSEnv {
              name = "typescript-fhs-dev"; # <-- Rename to your project

              targetPkgs = (fhs-pkgs: [
                fhs-pkgs.nodejs_24
                fhs-pkgs.bun
                fhs-pkgs.pnpm
                fhs-pkgs.git

                # Common native build deps
                fhs-pkgs.stdenv.cc.cc.lib
                fhs-pkgs.zlib
                fhs-pkgs.glibc
              ]);

              multiPkgs = fhs-pkgs: with fhs-pkgs; [
                zlib
              ];

              profile = ''
                export PATH="$HOME/.bun/bin:$PATH"
              '';

              allowSubstitutes = false;
            }).env;

          in
          {
            devShells.default = devShell;
            devShells.build = fhsEnv;
          }
        ));
    in
    mkEnvFromChannel nixpkgs-stable;
}
