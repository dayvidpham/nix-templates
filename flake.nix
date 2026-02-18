{
  description = "Reusable Nix flake templates for Python, TypeScript, and Go dev environments";

  outputs = { self, ... }: {
    templates = {
      python = {
        path = ./templates/python;
        description = "Python dev environment with dual nixpkgs channels and FHS build shell";
      };

      python-cuda = {
        path = ./templates/python-cuda;
        description = "Python dev environment with CUDA/NVIDIA GPU support, dual nixpkgs channels, and FHS build shell";
      };

      typescript = {
        path = ./templates/typescript;
        description = "TypeScript/Node.js dev environment with Bun, dual nixpkgs channels, and FHS build shell";
      };

      golang = {
        path = ./templates/golang;
        description = "Go dev environment with buildGoModule, race-enabled tests, and common tooling";
      };
    };
  };
}
