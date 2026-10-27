# nix-config

个人 NixOS / Home Manager 配置，主要用于桌面、服务器及其他 Linux 设备。

## 目录结构

- `flake.nix` — Flake 入口、依赖及主机配置
- `hosts/` — 各设备的独立配置
- `modules/` — NixOS 与 Home Manager 模块
- `profiles/` — 组合配置
- `pkgs/` — 自定义软件包
- `shells/` — devShell
- `scripts/` — 常用脚本
- `assets/` — 字体、壁纸等资源
- `cert/` — 证书文件
- `vendor/` — 第三方驱动

## 主机配置

| 主机         | 类型         | 用途             |
| ------------ | ------------ | ---------------- |
| `office`     | NixOS        | 办公工作站       |
| `aio`        | NixOS        | 家用AIO          |
| `moki`       | NixOS        | DN42             |
| `studio`     | NixOS        | 个人桌面         |
| `ali-server` | Home Manager | 云服务器         |
| `openEruler` | Home Manager | openEuler 开发机 |

## 使用

构建并应用 NixOS 配置：

```
sudo nixos-rebuild switch --flake .#office
```

仅构建，不应用：

```
nix build .#nixosConfigurations.office.config.system.build.toplevel
```

更新 Flake 依赖：

```
nix flake update
```

不同主机使用对应的配置名称即可。

部分配置依赖私有仓库 `private-nix-config`，用于管理加密密钥、个人服务及工作环境相关内容。公开仓库保留主机配置入口，完整求值需要相应的私有仓库访问权限。

## 资源来源

**壁纸**

`assets/wallpapers/black.png` 是纯黑占位图，供 Stylix 使用；现有配色保留为固定色板。

Plasma、Sway 和 Pywal 使用本地 `~/Pictures/wallpaper.png`，个人壁纸不随仓库分发。随机壁纸脚本读取本地 `~/Pictures/wallpapers/` 目录。

**字体**

`assets/fonts/851ShouShu-2.ttf` 使用 **851手書き雑フォント**。

- [字体原作者发布页及使用说明](https://pm85122.onamae.jp/851fontpage.html)

**第三方驱动**

`vendor/aic8800dc-linux-patched/` 收录 AIC8800DC 无线网卡驱动，用于相关 USB 无线网卡的 Linux 内核适配。来源及修改说明见该目录下的 README。

---

此仓库主要用于个人设备配置管理，同时公开供参考。部分配置求值依赖私有仓库，不保证可以直接用于其他设备。
