{
  description = "Developmet flake for nvimpager";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    neovim.url = "github:neovim/neovim?dir=contrib";
    neovim.inputs.nixpkgs.follows = "nixpkgs";
    neovim.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, neovim, ... }: {
    overlay = final: prev: {
      nvimpager = prev.nvimpager.overrideAttrs (oa: {
        version = "dev";
        src = ./.;
        preBuild = "version=$(bash ./nvimpager -v | sed 's/.* //')";
        buildFlags = oa.buildFlags ++ [ "VERSION=\${version}-dev" ];
      });
    };
  }
  // (let
    filter = builtins.filter (s: !nixpkgs.lib.strings.hasSuffix "-darwin" s);
    inherit (flake-utils.lib) eachSystem defaultSystems;
  in eachSystem (filter defaultSystems) (system:
  let
    stable = import nixpkgs { overlays = [ self.overlay ]; inherit system; };
    nightly = import nixpkgs { overlays = [ neovim.overlay self.overlay ]; inherit system; };
    mkShell = pkgs: pkgs.mkShell {
      inputsFrom = [ pkgs.nvimpager ];
      packages = with pkgs; [
        lua51Packages.luacov
        git
        tmux
        hyperfine
      ];
      shellHook = ''
        # to find nvimpager lua code in the current dir
        export LUA_PATH=./?.lua''${LUA_PATH:+\;}$LUA_PATH
        # fix for different terminals in a pure shell
        export TERM=xterm
        # print the neovim version we are using
        nvim --version | head -n 1
        '';
      };
  in rec {
    packages = {
      nvimpager = stable.nvimpager;
      nvimpager-with-nightly-neovim = nightly.nvimpager;
    };
    defaultPackage = stable.nvimpager;
    apps.nvimpager = flake-utils.lib.mkApp { drv = stable.nvimpager; };
    defaultApp = apps.nvimpager;
    devShell = devShells.stable;
    devShells = {
      stable = mkShell stable;
      nightly = mkShell nightly;
    };
  }));
}
