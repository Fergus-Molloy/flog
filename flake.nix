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
      perSystem = { self', pkgs, lib, ... }:
        let
          db-name = "flog_dev";
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
              GRANT ALL PRIVILEGES ON DATABASE ${db-name} TO postgres;
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
                  PGPASSWORD="postgres" psql -U postgres -h "${pg-host}" -d "${db-name}"
                '')
              ] ++ lib.optional stdenv.isLinux inotify-tools;
          };
        };
    };
}
