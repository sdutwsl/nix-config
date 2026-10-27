{pkgs}: let
  python = pkgs.python312;
in
  pkgs.mkShell {
    packages = [
      python
      pkgs.git
      pkgs.fish
      # pydub shells out to ffmpeg for the .acb/.awb audio plugins.
      pkgs.ffmpeg
    ];

    # GkmasObjectManager pins UnityPy<=1.10.18, which isn't in nixpkgs, so the
    # deps come from pip wheels. Their C extensions (texture2ddecoder, etcpak,
    # astc-encoder-py) dlopen libstdc++ and can't find it without this.
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
    ];

    shellHook = ''
      repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
      venv="$repo_root/.venv"
      if [ ! -d "$venv" ]; then
        echo "gkmas: creating $venv"
        ${python}/bin/python -m venv "$venv"
        "$venv/bin/python" -m pip install --upgrade pip
        "$venv/bin/python" -m pip install -r "$repo_root/requirements.txt" boto3
      fi
      source "$venv/bin/activate"
      if [[ $- == *i* && -t 0 ]]; then
        export SHELL=${pkgs.fish}/bin/fish
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  }
