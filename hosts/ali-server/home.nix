{ config, inputs, ... }:

{
  imports = [
    inputs.agenix.homeManagerModules.default
    ../../modules/home/base.nix
    ../../modules/home/services/nginx.nix
    ../../modules/home/services/derper.nix
    ../../modules/home/services/certs-service.nix
  ];

  targets.genericLinux.enable = true;

  age = {
    identityPaths = [ "${config.home.homeDirectory}/.ssh/id_rsa" ];
    secretsDir = "${config.home.homeDirectory}/.local/state/agenix";
    secretsMountPoint = "${config.home.homeDirectory}/.local/state/agenix.d";
    secrets.nginx-locations.file = inputs.privateConfig.lib.secretFile "ali-server-nginx-locations";
  };

  systemd.user.services.personal-nginx.Unit = {
    Requires = [ "agenix.service" ];
    After = [ "agenix.service" ];
  };
}
