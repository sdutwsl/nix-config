{ lib
, pkgs
, ...
}:
let
  personalKey = "550CD36167DE90E86C2184DCD15DBB036A4B7DDE";
in
{
  programs.gpg = {
    enable = true;
    package = pkgs.gnupg;
    settings.default-key = lib.mkDefault personalKey;
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 86400;
    maxCacheTtl = 86400;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-qt;
  };

  programs.bash.initExtra = ''
    export GPG_TTY="$(tty)"
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
  '';

  programs.fish.interactiveShellInit = ''
    set -gx GPG_TTY (tty)
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
  '';
}
