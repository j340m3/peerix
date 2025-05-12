{
  description = "Peer2Peer Nix-Binary-Cache";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: {
    nixosModules.peerix = import ./module.nix;
    overlays.default = import ./overlay.nix { inherit self; };
  } // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python3;
      packages = map (pkg: python.pkgs.${pkg}) (builtins.filter (v: builtins.isString v && (builtins.stringLength v) > 0) (builtins.split "\n" (builtins.readFile ./requirements.txt)));
    in {
      packages = rec {
        peerix-unwrapped = python.pkgs.buildPythonApplication {
          pname = "peerix";
          version = builtins.replaceStrings [ " " "\n" ] [ "" "" ] (builtins.readFile ./VERSION);
          src = ./.;

          doCheck = false;
    
          propagatedBuildInputs = with pkgs; [
            nix
            nix-serve
          ] ++ packages;
        };

        peerix = pkgs.writeShellScriptBin "peerix" ''
          PATH=${pkgs.nix}/bin:${pkgs.nix-serve}:$PATH
          exec ${peerix-unwrapped}/bin/peerix "$@"
        '';
      };

      packages.default = self.packages.${system}.peerix;

      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nix-serve
          niv
          (python.withPackages (ps: packages))
        ];
      };

      apps.default = { 
        type = "app"; 
        program = "${self.packages.${system}.peerix}/bin/peerix"; 
        meta = with nixpkgs.lib; {
            description = "Peerix is a peer-to-peer binary cache for nix derivations.";
            longDescription = ''
              Peerix implements a nix binary cache. When the nix package manager queries peerix, peerix
              will ask the network if any other peerix instances hold the package, and if some other instance
              holds the derivation, it will download the derivation from that instance.
            '';
            homepage = "https://github.com/j340m3/peerix";
            license = licenses.gpl3Only;
            maintainers = with maintainers; [  ]; #TODO
            platforms = platforms.all;
          };
        };
    });
}
