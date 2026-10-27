{pkgs}: let
  # be: Elixir / Phoenix
  beam = pkgs.beam28Packages;
  erlang = beam.erlang;
  elixir = beam.elixir_1_20;

  # fe: Rust / WASM. Channel must match blog/fe/rust-toolchain.toml.
  llvm = pkgs.llvmPackages_latest;
  rustToolchain = pkgs.rust-bin.nightly."2026-09-19".default.override {
    targets = ["x86_64-unknown-linux-gnu" "wasm32-unknown-unknown"];
    extensions = ["rust-analyzer" "rust-src" "rust-std"];
  };
in
  # stdenvNoLibs keeps host libc/libstdc++ out of the linker flags for wasm32.
  (pkgs.mkShell.override {stdenv = pkgs.stdenvNoLibs;}) {
    packages = [
      elixir
      erlang
      pkgs.esbuild
      pkgs.inotify-tools
      pkgs.mariadb
      pkgs.git
      pkgs.fish

      rustToolchain
      llvm.bintools
      llvm.libstdcxxClang
      pkgs.openssl
      pkgs.binaryen
      # cargo-leptos builds the server binary and the wasm from the one crate.
      # nixpkgs builds it with `no_downloads`, so it runs the wasm-bindgen CLI
      # from PATH and refuses to work unless that version matches the
      # wasm-bindgen crate exactly; blog/fe/Cargo.toml pins the crate to match.
      pkgs.cargo-leptos
      pkgs.wasm-bindgen-cli
    ];

    shellHook = ''
      # Keep hex/mix state under blog/be/.nix-shell (gitignored there).
      repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
      export HEX_HOME="$repo_root/be/.nix-shell/hex-archives"
      export MIX_HOME="$repo_root/be/.nix-shell/mix-archives"
      mkdir -p "$HEX_HOME" "$MIX_HOME"
      export MIX_REBAR3_PATH=${beam.rebar3}/bin/rebar3
      export PATH="$MIX_HOME/bin:$PATH"
      if [[ $- == *i* && -t 0 ]]; then
        export SHELL=${pkgs.fish}/bin/fish
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  }
