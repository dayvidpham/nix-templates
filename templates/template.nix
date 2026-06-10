{
  description = "Minimal Nix flake template to provision a template for environments scoped to one language";

  inputs = {
    nixpkgs-stable.url = "https://github.com/NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "https://github.com/NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "https://github.com/numtide/flake-utils";
  };

  outputs =
    { nixpkgs-stable
    , nixpkgs-unstable
    , flake-utils
    , ...
    }@args:
    let
      # ----------------------------------------------------------
      # You configure ...
      # ----------------------------------------------------------
      pname = "my-cool-project";
      version = "0.0.1";

      # default channel to source all packages
      nixpkgs-channel = nixpkgs-stable;

      # The core language packages (e.g., zig, ...)
      # Set to null to use the default core language version from nixpkgs
      coreLanguageAttr = null;

      # Vendor hash for buildGoModule (run `nix build` once with
      # lib.fakeHash to get the real hash from the error message)
      vendorHash = null; # null = vendored in repo; otherwise sha256 string

      # Extra CLI tools available in the dev shell
      devTools = pkgs: with pkgs; [
        # gopls         # LSP
        # gotools       # goimports, godoc, etc.
        # go-tools      # staticcheck
        # delve         # debugger
        # protobuf      # protoc
        # protoc-gen-go # protobuf Go codegen
      ];


      # POSIX shell hook executed upon devShell entry
      shellHook = ''
      '';


      # Native build dependencies (C libraries, system packages)
      nativeBuildDeps = pkgs: with pkgs; [
        # pkg-config
        # openssl
        # sqlite
      ];

      # Extra check commands run during `nix build` after go test
      customCheckPhase = ''
        # go vet ./...
        # staticcheck ./...
      '';

      # Files to install alongside the binary (relative to src)
      extraPostInstallPhase = ''
        # mkdir -p $out/share/policies
        # cp authz/policies/*.rego $out/share/policies/
      '';

      # ==========================================================
      # IMPLEMENTATION — you shouldn't need to edit below here
      # ==========================================================


      # ----------------------------------------------------------
      # FLows into outputs generator
      # ----------------------------------------------------------
      mkOutputs = nixpkgs-channel:
        flake-utils.lib.eachDefaultSystem (system:
          let
            pkgs = import nixpkgs-channel {
              inherit system;
              config.allowUnfree = true;
            };

            # ----------------------------------------------------------
            # Build
            # ----------------------------------------------------------

            package = pkgs.buildGoModule {
              inherit pname version;
              src = ./.;
              inherit vendorHash;

              nativeBuildInputs = nativeBuildDeps pkgs;

              checkPhase = ''
                runHook preCheck
                ${customCheckPhase}
                runHook postCheck
              '';

              postInstall = ''
                runHook prePostInstall
                ${extraPostInstallPhase}
                runHook postPostInstall
              '';
            };

            # ----------------------------------------------------------
            # Development Shell
            # ----------------------------------------------------------

            devShell = pkgs.mkShell {
              name = "${pname}-devShell";
              inputsFrom = [ package ];
              packages = (devTools pkgs);

              inherit shellHook;
            };

          in
          {
            packages.default = package;
            packages.${pname} = package;

            devShells.default = devShell;

            # Quick check: nix flake check
            checks.build = package;
          }
        );
    in
    mkOutputs nixpkgs-channel;
}
