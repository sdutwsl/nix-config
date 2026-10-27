{pkgs}: let
  androidSdk = (pkgs.androidenv.override {
    licenseAccepted = true;
  }).composeAndroidPackages {
    toolsVersion = null;
    # Cordova Android 15 tops out at API 36; keep it alongside latest.
    platformVersions = ["36" "latest"];
    buildToolsVersions = ["36.0.0" "latest"];
    includeEmulator = false;
    includeNDK = false;
  };

  sdk = androidSdk.androidsdk;
in
  pkgs.mkShell {
    packages = with pkgs; [
      nodejs
      jdk17
      gradle
      sdk
      fish
    ];

    JAVA_HOME = "${pkgs.jdk17}";
    ANDROID_HOME = "${sdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${sdk}/libexec/android-sdk";

    # Use aapt2 from the Nix store instead of the Maven-downloaded binary,
    # which can't run on NixOS.
    GRADLE_OPTS =
      "-Dorg.gradle.project.android.aapt2FromMavenOverride="
      + "${sdk}/libexec/android-sdk/build-tools/36.0.0/aapt2";

    shellHook = ''
      if [[ $- == *i* && -t 0 ]]; then
        export SHELL=${pkgs.fish}/bin/fish
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  }
