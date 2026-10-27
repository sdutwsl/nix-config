{ options, ... }: {
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;
  boot.tmp.cleanOnBoot = true;

  # unstable moved journald to a structured `settings` option; 26.05 still
  # only has `extraConfig`. Keys are case-sensitive for journald.
  services.journald =
    if options.services.journald ? settings then {
      settings.Journal = {
        SystemMaxUse = "500M";
        SystemMaxFileSize = "50M";
      };
    } else {
      extraConfig = ''
        SystemMaxUse=500M
        SystemMaxFileSize=50M
      '';
    };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # The NixOS manual is regenerated locally on every rebuild; skip it.
  documentation.nixos.enable = false;
}
