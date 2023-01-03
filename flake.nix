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
    overlays.default = final: prev: {
      nvimpager =
        let
          inherit (builtins) head match readFile;
          version = head (match ".*version=([0-9.]*)\n.*" (readFile ./nvimpager))
            + "-dev-${toString self.sourceInfo.lastModifiedDate}";
        in prev.nvimpager.overrideAttrs (oa: {
          inherit version;
          src = ./.;
          buildFlags = oa.buildFlags ++ [ "VERSION=${version}" ];
          checkPhase = ''
            runHook preCheck
            script -ec "busted --lpath './?.lua' --filter-out 'handles man' test"
            runHook postCheck
          '';
        });
    };
  }
  // (let
    filter = builtins.filter (s: !nixpkgs.lib.strings.hasSuffix "-darwin" s);
    inherit (flake-utils.lib) eachSystem defaultSystems;
  in eachSystem (filter defaultSystems) (system:
  let
    stable = import nixpkgs { overlays = [ self.overlays.default ]; inherit system; };
    nightly = import nixpkgs { overlays = [ neovim.overlay self.overlays.default ]; inherit system; };
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
  in {
    apps.default = flake-utils.lib.mkApp { drv = stable.nvimpager; };
    devShells.default = mkShell stable;
    devShells.nightly = mkShell nightly;
    packages.default = stable.nvimpager;
    packages.nightly = nightly.nvimpager;
  }));
}
