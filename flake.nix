{
  description = "Reusable Nix flake templates for Python and TypeScript dev environments";

  outputs = { self, ... }: {
    templates = {
      python = {
        path = ./templates/python;
        description = "Python dev environment with optional CUDA/NVIDIA support, dual nixpkgs channels, and FHS build shell";
      };

      typescript = {
        path = ./templates/typescript;
        description = "TypeScript/Node.js dev environment with Bun, dual nixpkgs channels, and FHS build shell";
      };
    };
  };
}
