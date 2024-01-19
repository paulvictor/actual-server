{
  description = "Example of a project that integrates nix flake with yarn.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        bcrypt-hashes = {
          "linux-x64" = "1b1hfc6xx99v3hp3hczrmi5ka1ccd96j330r51pzksg15qr1wmr3";
          "linux-arm64" = "038iaqvsm2s7mn71m0akrpidzai95sbr5hwcy8i5yq8b8bp53h5b";
        };
        better-sqlite3-hashes = {
          "linux-x64" = "0p8iyj5xiqnxzj2n700hkfcghk7z9kk0pknpyvrnif58gs3y8zk3";
          "linux-arm64" = "sha256-0Ubo+EqpHxn0u1/hL8LXFaqhwuegIgEsK9iz+ceHTKM=";
        };
        system-to-node-system =
          if system == "x86_64-linux"
          then "linux-x64"
          else if system == "aarch64-linux"
          then "linux-arm64"
          else throw "Unsupported system for shims";
        bcrypt_lib =
          let
            bcrypt_version = "5.1.0";
          in pkgs.fetchurl {
            url = "https://github.com/kelektiv/node.bcrypt.js/releases/download/v${bcrypt_version}/bcrypt_lib-v${bcrypt_version}-napi-v3-${system-to-node-system}-glibc.tar.gz"; # TODO Add other Systems
            sha256 = bcrypt-hashes.${system-to-node-system};
          };

        better-sqlite3 =
          let
            version = "9.1.1";
          in pkgs.fetchurl {
            url = "https://github.com/WiseLibs/better-sqlite3/releases/download/v${version}/better-sqlite3-v${version}-node-v115-${system-to-node-system}.tar.gz"; # TODO Add other Systems
            sha256 = better-sqlite3-hashes.${system-to-node-system};
          };

        node-modules = pkgs.mkYarnPackage {
          name = "node-modules";
          src = ./.;
          postInstall = ''
            # Fix bcrypt node module
            cd $out/libexec/actual-sync/node_modules/bcrypt
            mkdir -p ./lib/binding && tar -C ./lib/binding -xf ${bcrypt_lib}

            # Fix better-sqlite3 node module
            cd $out/libexec/actual-sync/node_modules/better-sqlite3
            tar -C . -xf ${better-sqlite3}
          '';
        };

        actual = pkgs.stdenv.mkDerivation {
          name = "actual";
          src = ./.;
          buildInputs = [pkgs.yarn node-modules pkgs.typescript];
          buildPhase = ''
            ln -s ${node-modules}/libexec/actual-sync/node_modules node_modules
            ${pkgs.yarn}/bin/yarn build
          '';
          installPhase =  ''
            mkdir -pv $out
            cp -R build $out/
            cp -R $src/src/sql $out/build/src/sql
            ln -s ${node-modules}/libexec/actual-sync/node_modules $out/build/node_modules
            cp package.json $out/build/
          '';

        };
      in
        {
          packages = {
            inherit node-modules;
            default = actual;
            runner = pkgs.writeShellScriptBin "actual-server"
              "${pkgs.nodejs}/bin/node ${actual}/build/app.js";
          };
        }
    );
}
