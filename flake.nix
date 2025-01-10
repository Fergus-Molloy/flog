{
  description = "A flake to run all services needed for development of flog";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { self', pkgs, lib, system, ... }:
        let
          db-name = "flog";
          pg-host = "127.0.0.1";
          postgres = {
            enable = true;
            listen_addresses = pg-host;
            initialDatabases = [
              {
                name = db-name;
              }
            ];
            initialScript.after = ''
              CREATE USER postgres WITH PASSWORD 'postgres' SUPERUSER;
              GRANT ALL PRIVILEGES ON DATABASE ${db-name}_dev TO postgres;
              GRANT ALL PRIVILEGES ON SCHEMA public TO postgres;
            '';
          };
        in
        {
          # This adds a `self.packages.default`
          process-compose."default" = { config, ... }:
            {
              imports = [
                inputs.services-flake.processComposeModules.default
              ];
              settings = {
                processes = {
                  "phoenix" = {
                    command = "mix phx.server";
                    depends_on."pg".condition = "process_healthy";
                  };
                };
              };

              services.postgres."pg" = postgres;
            };
          process-compose."db" = { config, ... }:
            {
              imports = [
                inputs.services-flake.processComposeModules.default
              ];
              services.postgres."pg" = postgres;
            };

          # package app (I don't think it supports js deps but who needs those anyway)
          packages.flog =
            let
              beamPackages = with pkgs; beam.packagesWith beam.interpreters.erlang_27;
              pname = "cardz";
              version = "0.1.0";
              src = ./.;
              elixir = pkgs.elixir_1_18;
              mixFodDeps = beamPackages.fetchMixDeps {
                pname = "mix-deps-${pname}";
                inherit src version;
                sha256 = "9C+276faxhH4TnG/a9WChc07PoXi6RmKcBmIDSkwE3Y=";
              };
              translatedPlatform =
                {
                  aarch64-darwin = "macos-arm64";
                  aarch64-linux = "linux-arm64";
                  armv7l-linux = "linux-armv7";
                  x86_64-darwin = "macos-x64";
                  x86_64-linux = "linux-x64";
                }.${system};
            in
            beamPackages.mixRelease
              {
                inherit pname version src mixFodDeps;
                env = {
                  # i'm grabbing package version from env vars
                  VERSION = version;
                };
                # makes output non-deterministic, deployment should generate their own cookie really
                removeCookie = false;
                # mix will try to download these if we don't install them
                preBuild = ''
                  install -D ${pkgs.tailwindcss}/bin/tailwindcss _build/tailwind-${translatedPlatform}
                  install -D ${pkgs.esbuild}/bin/esbuild _build/esbuild-${translatedPlatform}

                  mix phx.gen.release
                '';
                postInstall = ''
                  head -c 64 /dev/urandom | base64 | tr -d "\n" | sed 's/\(.*\)/SECRET="\1"/' > $out/.env
                '';
                postBuild = ''
                  mix assets.deploy
                '';
              };
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs;
              [
                elixir_1_18
                elixir-ls

                nodejs_22

                postgresql

                nil
                nixpkgs-fmt
                (pkgs.writeShellScriptBin "pg-connect" ''
                  PGPASSWORD="postgres" psql -U postgres -h "${pg-host}" -d "${db-name}_dev"
                '')
                (pkgs.writeShellScriptBin "pg-connect-prod" ''
                  psql -U "${db-name}" -h "handler.home" -d "${db-name}_prod"
                '')
              ] ++ lib.optional stdenv.isLinux inotify-tools;
          };
        };
    };
}
