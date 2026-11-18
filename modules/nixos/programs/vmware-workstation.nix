{ pkgs, ... }:

{
  virtualisation.vmware.host.enable = true;

  # autoPatchelf breaks the non-PIE vmnet-natd (PHDR outside any LOAD) and ld.so
  # segfaults on it, so ship the pristine binary and let nix-ld load it.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = [ pkgs.openssl ];
  virtualisation.vmware.host.package = pkgs.vmware-workstation.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      cp $out/bin/vmnet-natd $NIX_BUILD_TOP/vmnet-natd.orig
    '';
    postPhases = (old.postPhases or [ ]) ++ [ "fixVmnetNatdPhase" ];
    fixVmnetNatdPhase = ''
      install -m555 $NIX_BUILD_TOP/vmnet-natd.orig $out/bin/vmnet-natd
    '';
  });

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
