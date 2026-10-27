{ lib
, stdenv
, kernel
, kmod
, bc
}:

stdenv.mkDerivation {
  pname = "aic8800dc";
  version = "local";

  src = ../vendor/aic8800dc-linux-patched;

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [
    kmod
    bc
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    make -C drivers/aic8800 \
      KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      KVER=${kernel.modDirVersion} \
      PWD=$PWD/drivers/aic8800 \
      modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    moddir=$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/aic8800
    mkdir -p "$moddir"

    install -Dm644 drivers/aic8800/aic_load_fw/aic_load_fw.ko "$moddir/aic_load_fw.ko"
    install -Dm644 drivers/aic8800/aic8800_fdrv/aic8800_fdrv.ko "$moddir/aic8800_fdrv.ko"

    mkdir -p "$out/lib/firmware"
    cp -r fw/aic8800DC "$out/lib/firmware/"

    runHook postInstall
  '';

  meta = {
    description = "AICSemi AIC8800DC USB Wi-Fi driver";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}