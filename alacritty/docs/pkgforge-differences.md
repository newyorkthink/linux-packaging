# Alacritty 上游打包差异

## 来源

参考 [pkgforge-dev/alacritty-AppImage](https://github.com/pkgforge-dev/alacritty-AppImage) 的 `main` 提交 `b709110c90c204e2ab4838665ebb953a589b4d05`：[依赖与编译](https://github.com/pkgforge-dev/alacritty-AppImage/blob/b709110c90c204e2ab4838665ebb953a589b4d05/get-dependencies.sh)、[封装脚本](https://github.com/pkgforge-dev/alacritty-AppImage/blob/b709110c90c204e2ab4838665ebb953a589b4d05/make-appimage.sh)、[工作流](https://github.com/pkgforge-dev/alacritty-AppImage/blob/b709110c90c204e2ab4838665ebb953a589b4d05/.github/workflows/appimage.yml)。本次核对未直接复用其独立构建命令。

| 上游处理 | 可确认的用途 | 本仓库取舍及依据 |
| --- | --- | --- |
| `cargo fetch --locked --target ...`、`cargo build --release --locked --offline`、`cargo test --locked --offline` | 取齐锁定依赖，离线构建并执行测试。 | 未采用。保留本程序已有 `cargo build --release` 及补丁顺序，不因上游差异改动现行编译流程。 |
| `quick-sharun ./AppDir/bin/alacritty /usr/lib/libedit.so*`、`quick-sharun --make-appimage` | 收集依赖并构建 AppImage。 | 未采用。已有输入故障记录要求继续使用 LinuxDeploy，不能回到 quick-sharun。 |
| `ADD_HOOKS="self-updater.hook"` 和 `UPINFO="gh-releases-zsync|..."` | 配置上游 AppImage 自更新。 | 未采用。当前发布由本仓库 GitHub Actions 管理，不额外增加 hook。 |
| Arch 容器、`pacman` 依赖安装 | 提供上游编译及封装环境。 | 未采用。Alacritty 沿用 Ubuntu 22.04、公共 APT 入口和 LinuxDeploy。 |
| 官方 desktop、SVG 图标 | 提供桌面入口和程序图标。 | 保留本仓库从对应正式版源码取得资源的既有做法；本仓库复制命令不冒称上游原样代码。 |

上游并未逐项说明其做法与本仓库 X11 IME 故障的关系，不能自行推断官方原因。具体代码与验证边界见[专属差异](./template-deviations.md)，本仓库历史故障见 [README](../README.md)。
