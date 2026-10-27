{ pkgs, ... }:

{
  # /var/lib/swapfile lives on the office root filesystem.
  boot.resumeDevice = "/dev/disk/by-uuid/5aefea59-00d0-4abc-a53c-edb5c16a1b6d";
  boot.kernelParams = [
    "resume_offset=127086592"
  ];

  systemd.services.hibernate-to-windows = {
    description = "Hibernate Linux and reboot into Windows";

    path = [
      pkgs.coreutils
      pkgs.systemd
    ];

    serviceConfig = {
      Type = "oneshot";
      # The service continues only after the hibernated Linux session is
      # resumed, which may happen hours or days later.
      TimeoutStartSec = "infinity";
    };

    script = ''
      set -eu

      override_dir=/run/systemd/sleep.conf.d
      override_file="$override_dir/90-hibernate-to-windows.conf"
      oneshot_set=0

      cleanup() {
        rm -f "$override_file"
        if [ "$oneshot_set" -eq 1 ]; then
          bootctl set-oneshot "" || true
        fi
      }
      trap cleanup EXIT INT TERM

      mkdir -p "$override_dir"
      cat > "$override_file" <<'EOF'
      [Sleep]
      HibernateMode=reboot
      EOF

      # Only the next boot should enter Windows.
      bootctl set-oneshot auto-windows
      oneshot_set=1

      # HibernateMode=reboot writes the image and then immediately reboots.
      # When Linux is entered again, this call returns after resume and the
      # EXIT trap removes the temporary override.
      systemctl hibernate
      oneshot_set=0
    '';
  };
}
