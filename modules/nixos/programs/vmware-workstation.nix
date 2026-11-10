{ pkgs, ... }:

{
  virtualisation.vmware.host.enable = true;

  boot.kernelPackages = pkgs.linuxPackages.extend (_: prev: {
    vmware = prev.vmware.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        for module in vmmon vmnet; do
          ${pkgs.kmodigest}/bin/kmodigest "$out/lib/modules/${prev.kernel.modDirVersion}/misc/$module.ko"
        done
      '';
    });
  });
}
