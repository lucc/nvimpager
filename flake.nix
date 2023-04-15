{
  description = "Developmet flake for nvimpager";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    neovim.url = "github:neovim/neovim?dir=contrib";
    neovim.inputs.nixpkgs.follows = "nixpkgs";
    neovim.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, neovim, ... }:
  let
    inherit (builtins) filter head match readFile;
    inherit (flake-utils.lib) eachSystem defaultSystems;
    version = head (match ".*version=([0-9.]*)\n.*" (readFile ./nvimpager))
              + "-dev-${toString self.sourceInfo.lastModifiedDate}";
    withoutDarwin = filter (s: !nixpkgs.lib.strings.hasSuffix "-darwin" s);
    mkShell = pkgs: pkgs.mkShell {
      inputsFrom = [ pkgs.nvimpager ];
      packages = with pkgs; [ lua51Packages.luacov git tmux hyperfine ];
      shellHook = ''
        # fix for different terminals in a pure shell
        export TERM=xterm
        # print the neovim version we are using
        nvim --version | head -n 1
      '';
    };
  in ({
    overlays.default = final: prev: {
      nvimpager = prev.nvimpager.overrideAttrs (oa: {
        inherit version;
        src = ./.;
        buildFlags = oa.buildFlags ++ [ "VERSION=${version}" ];
        checkPhase = ''
          runHook preCheck
          make test BUSTED='busted --output TAP --filter-out "handles man"'
          runHook postCheck
        '';
      });
    };
  } // (eachSystem (withoutDarwin defaultSystems) (system:
  let
    stable = import nixpkgs { overlays = [ self.overlays.default ]; inherit system; };
    nightly = import nixpkgs { overlays = [ neovim.overlay self.overlays.default ]; inherit system; };
  in {
    apps.default = flake-utils.lib.mkApp { drv = stable.nvimpager; };
    devShells.default = mkShell stable;
    devShells.nightly = mkShell nightly;
    packages.default = stable.nvimpager;
    packages.nightly = nightly.nvimpager;
  })));
}
