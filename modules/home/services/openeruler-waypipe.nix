{ config, pkgs, ... }:

let
  ssh = "${pkgs.openssh}/bin/ssh";
  home = config.home.homeDirectory;
  display = "${home}/.local/state/wayland-office";
in
{
  # Lets Claude Code and Codex on openeruler read the local clipboard on demand.
  # openeruler has no XDG_RUNTIME_DIR, so the display needs an absolute path, and a
  # fixed path only fits one connection: keep it here instead of wrapping ssh.
  systemd.user.services.openeruler-waypipe = {
    Unit = {
      Description = "Forward Wayland to openeruler";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      # A dropped connection can leave the socket behind, and waypipe won't bind over it.
      ExecStartPre = "${ssh} -o BatchMode=yes openeruler rm -f ${display}";
      # waypipe can't restrict protocols; the allowlist limits the remote to the clipboard.
      ExecStart = "${pkgs.wl-proxy}/bin/wl-veil -i -f wl_seat -f ext_data_control_manager_v1 -- ${pkgs.waypipe}/bin/waypipe --no-gpu --ssh-bin ${ssh} --remote-bin ${home}/.nix-profile/bin/waypipe --display ${display} ssh -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 openeruler sleep infinity";
      Restart = "always";
      RestartSec = 10;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
