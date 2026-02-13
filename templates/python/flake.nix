{
  description = "Reproducible Python dev environment with optional CUDA support";

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
      # ==========================================================
      # PROJECT CONFIGURATION — edit this section for your project
      # ==========================================================

      # Set to true to enable CUDA/NVIDIA GPU support
      enableCuda = false;

      # Python version (nixpkgs attribute name)
      pythonAttr = "python313";

      # Python packages available via `import` in the interpreter
      pythonPackages = ps: with ps; [
        pip
        virtualenv
        tkinter
        # Add your packages here: numpy, pandas, requests, etc.
      ];

      # CLI tools available in $PATH
      cliTools = pkgs_: [
        pkgs_.uv                                    # Package installer
        pkgs_.mypy                                  # Type checker
        pkgs_.${pythonAttr + "Packages"}.ruff       # Linter/formatter
      ];

      # Native build dependencies (C libraries, compilers)
      nativeBuildDeps = pkgs_: with pkgs_; [
        zlib
        glibc
        stdenv.cc.cc.lib
        gcc
        tk
        tcl
        libxcrypt
      ];

      # ==========================================================
      # IMPLEMENTATION — you shouldn't need to edit below here
      # ==========================================================

      mkEnvFromChannel = (nixpkgs-channel:
        flake-utils.lib.eachDefaultSystem (system:
          let
            # ----------------------------------------------------------
            # Package Set Configuration
            # ----------------------------------------------------------

            pkgs = import nixpkgs-channel ({
              inherit system;
              config.allowUnfree = true;
            } // (if enableCuda then {
              config.cudaSupport = true;
              config.cudaVersion = "13";
            } else { }));

            # ----------------------------------------------------------
            # Python Environment
            # ----------------------------------------------------------

            pythonWithPkgs = pkgs.${pythonAttr}.withPackages pythonPackages;

            pythonWrapper = pkgs.writeShellScriptBin "python3" ''
              export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
              exec ${pythonWithPkgs}/bin/python3 "$@"
            '';

            # ----------------------------------------------------------
            # NVIDIA/CUDA Configuration (conditional on enableCuda)
            # ----------------------------------------------------------

            nvidiaBuildInputs = pkgs_: with pkgs_; [
              ffmpeg
              fmt.dev
              libGLU
              libGL
              xorg.libXi
              xorg.libXmu
              freeglut
              xorg.libXext
              xorg.libX11
              xorg.libXv
              xorg.libXrandr
              zlib
              ncurses
              stdenv.cc
              binutils
              wayland
            ];

            nvidiaShellHook = pkgs_: with pkgs_; ''
              export CMAKE_PREFIX_PATH="${pkgs_.fmt.dev}:$CMAKE_PREFIX_PATH"
              export PKG_CONFIG_PATH="${pkgs_.fmt.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
              export EXTRA_CCFLAGS="-I/usr/include"
            '';

            # ----------------------------------------------------------
            # Development Shell
            # ----------------------------------------------------------

            devShell = pkgs.mkShell {
              name = "python-dev"; # <-- Rename to your project

              buildInputs =
                (nativeBuildDeps pkgs)
                ++ (if enableCuda then (nvidiaBuildInputs pkgs) else [ ]);

              packages = [ pythonWrapper ] ++ (cliTools pkgs);

              shellHook =
                let
                  tk = pkgs.tk;
                  tcl = pkgs.tcl;
                in
                ''
                  export LD_LIBRARY_PATH="$NIX_LD_LIBRARY_PATH:$LD_LIBRARY_PATH"
                  export TK_LIBRARY="${tk}/lib/${tk.libPrefix}"
                  export TCL_LIBRARY="${tcl}/lib/${tcl.libPrefix}"

                  ${if enableCuda then (nvidiaShellHook pkgs) else ""}

                  if [[ -d .venv ]]; then
                    VENV_PYTHON="$(readlink -f ./.venv/bin/python)"
                    echo "Found .venv/bin/python: $VENV_PYTHON"
                    export PYTHONPATH=".venv/lib/python3.13/site-packages:$PYTHONPATH"
                  fi
                '';

              allowSubstitutes = false;
            };

            # ----------------------------------------------------------
            # FHS Environment
            # For packages requiring traditional Linux filesystem layout
            # ----------------------------------------------------------

            fhsEnv = (pkgs.buildFHSEnv {
              name = "python-fhs-dev"; # <-- Rename to your project

              targetPkgs = (fhs-pkgs:
                let
                  fhsPython = fhs-pkgs.${pythonAttr}.withPackages pythonPackages;
                in
                [ fhsPython fhs-pkgs.git ]
                ++ (cliTools fhs-pkgs)
                ++ (nativeBuildDeps fhs-pkgs)
                ++ (if enableCuda then (nvidiaBuildInputs fhs-pkgs) else [ ])
              );

              multiPkgs = fhs-pkgs: with fhs-pkgs; [
                zlib
                libxcrypt-legacy
              ];

              # profile is a string attr (not a function), so we use the outer
              # pkgs for nvidiaShellHook — same package set as fhs-pkgs.
              profile = ''
                export LD_LIBRARY_PATH="$NIX_LD_LIBRARY_PATH:$LD_LIBRARY_PATH"
                ${if enableCuda then ''
                  export EXTRA_CCFLAGS="-I/usr/include"
                  ${nvidiaShellHook pkgs}
                '' else ""}
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
