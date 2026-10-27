{ pkgs, ... }:

let
  wine = pkgs.wineWow64Packages.stableFull;

  subahibi = pkgs.writeShellApplication {
    name = "subahibi";

    runtimeInputs = [
      wine
      pkgs.coreutils
      pkgs.gnugrep
    ];

    text = ''
      export WINEPREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/subahibi"

      GAME_DIR="$HOME/apps/美好的每一天 ～不连续的存在～"
      GAME_EXE="$GAME_DIR/BGI-CHS.exe"

      FONT_SRC="$GAME_DIR/font.ttf"
      FONT_DST="$WINEPREFIX/drive_c/windows/Fonts/subahibi.ttf"

      if [ ! -f "$GAME_EXE" ]; then
        echo "找不到游戏：$GAME_EXE"
        exit 1
      fi

      #
      # 创建 Wine prefix
      # 注意：这里不使用 zh_CN locale
      #
      if [ ! -f "$WINEPREFIX/system.reg" ]; then
        echo "首次运行：创建 Wine prefix..."

        mkdir -p "$WINEPREFIX"

        wineboot -u
        wineserver -w

        echo "Wine prefix 创建完成。"
      fi

      #
      # 检查字体
      #
      if [ ! -f "$FONT_SRC" ]; then
        echo "找不到字体：$FONT_SRC"
        exit 1
      fi

      NEED_FONT=0

      if [ ! -f "$FONT_DST" ]; then
        NEED_FONT=1
      elif ! cmp -s "$FONT_SRC" "$FONT_DST"; then
        NEED_FONT=1
      fi

      if ! wine reg query \
        'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
        /v 'SimHei (TrueType)' 2>/dev/null |
        grep -qi 'subahibi.ttf'
      then
        NEED_FONT=1
      fi

      #
      # 安装字体
      #
      if [ "$NEED_FONT" -eq 1 ]; then
        echo "安装游戏字体..."

        mkdir -p "$WINEPREFIX/drive_c/windows/Fonts"

        cp -f "$FONT_SRC" "$FONT_DST"

        wine reg add \
          'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
          /v 'SimHei (TrueType)' \
          /t REG_SZ \
          /d 'subahibi.ttf' \
          /f

        wineboot -u
        wineserver -w

        echo "字体安装完成。"
      fi

      #
      # 只有游戏使用中文 locale
      #
      cd "$GAME_DIR"

      exec env \
        LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive" \
        LANG="zh_CN.UTF-8" \
        LC_ALL="zh_CN.UTF-8" \
        wine BGI-CHS.exe
    '';
  };
in
{
  home.packages = [
    wine
    subahibi
  ];
}