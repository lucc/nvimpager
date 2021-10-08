{
  description = "Developmet flake for nvimpager";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    neovim.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, neovim, ... }: {
    overlay = final: prev: {
      nvimpager = prev.nvimpager.overrideAttrs (oa: {
        version = "dev";
        src = ./.;
      });
    };
  }
  //
  flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = import nixpkgs { overlays = [ self.overlay ]; inherit system; };
    nightly = import nixpkgs { overlays = [ neovim.overlay self.overlay ]; inherit system; };
  in rec {
    packages = {
      nvimpager = pkgs.nvimpager;
      nvimpager-with-nightly-neovim = nightly.nvimpager;
    };
    defaultPackage = pkgs.nvimpager;
    apps.nvimpager = flake-utils.lib.mkApp { drv = pkgs.nvimpager; name = "nvimpager"; };
    defaultApp = apps.nvimpager;
    devShell = pkgs.mkShell {
      inputsFrom = [ defaultPackage ];
      packages = with pkgs; [
        lua51Packages.luacov
        git
        tmux
        hyperfine
      ];
      shellHook = ''
        # to find nvimpager lua code in the current dir
        export LUA_PATH=./?.lua''${LUA_PATH:+\;}$LUA_PATH
        # fix for my terminal in a pure shell
        if [ "$TERM" = xterm-termite ]; then
          export TERM=xterm
        fi
      '';
    };
  }
  );
}
