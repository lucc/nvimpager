{
  description = "Developmet flake for nvimpager";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    overlay = final: prev:
      let pkgs = nixpkgs.legacyPackages.${prev.system};
      in rec {
        nvimpager = pkgs.nvimpager.overrideAttrs (oa: {
          version = "dev";
          src = ./.;
        });
      };
  }
  //
  flake-utils.lib.eachDefaultSystem (system:
    let pkgs = import nixpkgs {
      overlays = [ self.overlay ];
      inherit system;
    };
    in rec {
      packages = { inherit (pkgs.nvimpager); };
      defaultPackage = pkgs.nvimpager;
      apps.nvimpager = flake-utils.lib.mkApp { drv = pkgs.nvimpager; name = "nvimpager"; };
      defaultApp = apps.nvimpager;
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          neovim
          ncurses # for tput
          procps # for nvim_get_proc()

          lua51Packages.busted
          lua51Packages.luacov
          git
          scdoc
          tmux
          hyperfine
        ];
        #TERM = "xterm";
        shellHook = "export LUA_PATH=./?.lua\${LUA_PATH:+';'}$LUA_PATH";
      };
    }
  );
}
