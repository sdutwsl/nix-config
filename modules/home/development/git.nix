{ lib, pkgs, ... }:
let
  personalKey = "550CD36167DE90E86C2184DCD15DBB036A4B7DDE";
  personalIdentity = pkgs.writeText "git-personal-identity" ''
    [user]
      name = sdutwsl
      email = sdutwsl@gmail.com
      signingKey = ${personalKey}
  '';
in
{
  programs.git = {
    enable = true;
    includes = lib.mkBefore [{ path = personalIdentity; }];
    signing.signByDefault = true;
    settings = {
      alias = {
        identity-personal = "!git config --local user.name 'sdutwsl' && git config --local user.email 'sdutwsl@gmail.com' && git config --local user.signingkey '${personalKey}'";
      };
    };
  };
}
