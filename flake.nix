{
  description = "Developmet flake for nvimpager";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    neovim.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, neovim, ... }:
  let
    inherit (builtins) filter head match readFile;
    inherit (flake-utils.lib) eachSystem defaultSystems;
    version = head (match ".*version=([0-9.]*)\n.*" (readFile ./nvimpager))
              + "-dev-${toString self.sourceInfo.lastModifiedDate}";
    withoutDarwin = filter (s: !nixpkgs.lib.strings.hasSuffix "-darwin" s);
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
  } // (eachSystem (withoutDarwin defaultSystems) (system:
  let
    callPackage = (import nixpkgs { inherit system; }).callPackage nvimpager;
    neovim-nightly = neovim.packages.${system}.default;
    default = callPackage {};
    nightly = callPackage { neovim = neovim-nightly; };
  in {
    apps.default = flake-utils.lib.mkApp { drv = default; };
    packages = { inherit default nightly; };
  })));
}
