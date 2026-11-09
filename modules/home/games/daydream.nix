{ pkgs, ... }:

let
  wine = pkgs.wineWow64Packages.stableFull;

  daydream = pkgs.writeShellApplication {
    name = "daydream";

    runtimeInputs = [
      wine
      pkgs.coreutils
    ];

    text = ''
      export WINEPREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/daydream"

      GAME_DIR="/sdcard/e/Games/Cyanotype Daydream"
      GAME_EXE="$GAME_DIR/cs2.exe"

      FONT_DIR="$WINEPREFIX/drive_c/windows/Fonts"
      FONT_STAMP="$WINEPREFIX/.daydream-fonts-v2"

      if [ ! -f "$GAME_EXE" ]; then
        echo "找不到游戏：$GAME_EXE"
        exit 1
      fi

      mkdir -p "$WINEPREFIX"

      #
      # 安装游戏自带字体
      # startup.xml 用的是日文字体名，非日文 locale 下 Wine 不认，映射到英文名
      #
      if [ ! -f "$FONT_STAMP" ]; then
        echo "安装游戏字体..."

        mkdir -p "$FONT_DIR"
        cp -f "$GAME_DIR"/font/* "$FONT_DIR"/

        for name in '源真ゴシック Medium' 'ＭＳ ゴシック'; do
          LC_ALL=C.UTF-8 wine reg add \
            'HKCU\Software\Wine\Fonts\Replacements' \
            /v "$name" \
            /t REG_SZ \
            /d 'Gen Shin Gothic Medium' \
            /f
        done

        #
        # 系统对话框：zh_TW 下 MS Shell Dlg 指向不存在的 PMingLiU，正文用 Tahoma，都没有中文字形
        #
        for name in 'PMingLiU' 'MingLiU'; do
          LC_ALL=C.UTF-8 wine reg add \
            'HKCU\Software\Wine\Fonts\Replacements' \
            /v "$name" \
            /t REG_SZ \
            /d 'Source Han Sans SC' \
            /f
        done

        LC_ALL=C.UTF-8 wine reg add \
          'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' \
          /v 'Tahoma' \
          /t REG_SZ \
          /d 'Source Han Sans SC' \
          /f

        wineserver -w
        touch "$FONT_STAMP"

        echo "字体安装完成。"
      fi

      cd "$GAME_DIR"

      #
      # startup.xml 里简体中文的语言代码是 1028（zh-TW），所以用 zh_TW 而不是 zh_CN
      #
      exec env \
        LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive" \
        LANG="zh_TW.UTF-8" \
        LC_ALL="zh_TW.UTF-8" \
        wine cs2.exe
    '';
  };
in
{
  home.packages = [
    wine
    daydream
  ];
}
