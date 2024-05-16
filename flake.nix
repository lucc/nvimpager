{
  description = "Developmet flake for nvimpager";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    neovim.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, neovim, ... }:
  let
    inherit (builtins) head match readFile;
    inherit (flake-utils.lib) eachDefaultSystem;
    version = head (match ".*version=([0-9.]*)\n.*" (readFile ./nvimpager))
              + "-dev-${toString self.sourceInfo.lastModifiedDate}";
    nvimpager = {
      stdenv, neovim, ncurses, procps, scdoc, lua51Packages, util-linux
    }:
    stdenv.mkDerivation {
      pname = "nvimpager";
      inherit version;

      src = self;

      buildInputs = [
        ncurses # for tput
        procps # for nvim_get_proc() which uses ps(1)
      ];
      nativeBuildInputs = [ scdoc ];

      makeFlags = [ "PREFIX=$(out)" "VERSION=${version}" ];
      buildFlags = [ "nvimpager.configured" "nvimpager.1" ];
      preBuild = ''
      patchShebangs nvimpager
      substituteInPlace nvimpager --replace ':-nvim' ':-${neovim}/bin/nvim'
      '';

      doCheck = true;
      nativeCheckInputs = [ lua51Packages.busted util-linux neovim ];
      # filter out one test that fails in the sandbox of nix
      preCheck = let
        exclude-tags = if stdenv.isDarwin then "nix,mac" else "nix";
      in ''
      checkFlagsArray+=('BUSTED=busted --output TAP --exclude-tags=${exclude-tags}')
       '';
    };
  in ({
    overlays.default = final: prev: {
      nvimpager = final.callPackage nvimpager {};
    };
  } // (eachDefaultSystem (system:
  let
    pkgs = import nixpkgs { inherit system; };
    callPackage = pkgs.callPackage nvimpager;
    neovim-nightly = neovim.packages.${system}.default;
    default = callPackage {};
    nightly = callPackage { neovim = neovim-nightly; };
  in {
    apps.default = flake-utils.lib.mkApp { drv = default; };
    packages = { inherit default nightly; };
    packages.ldoc = pkgs.runCommandLocal "nvimpager-api-docs" {}
      "cd ${self} && ${pkgs.luaPackages.ldoc}/bin/ldoc . --dir $out";
  })));
}
