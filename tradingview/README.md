# TradingView AppImage

## 用途与产物

本目录把 TradingView 官方 Snap 的当前 `latest/stable` amd64 版本重新封装为 `tradingview.AppImage`，由 `.github/workflows/build.yml` 的标准 Arch Linux matrix 构建。AUR 的 [tradingview 配方](https://aur.archlinux.org/packages/tradingview)用作上游目录布局和依赖参考；正式构建直接获取官方 Snap，不依赖 AUR 维护者更新版本。

## 打包方式

- `common/snap/download_stable_snap.sh` 从 Snap Store 读取当前稳定版，核对发布者、架构和官方 SHA3-384，再下载 Snap。
- `common/archive/extract_archive.sh` 解包 Snap。构建脚本保留 TradingView 自带的 Electron/Chromium 程序、相邻库和资源，去掉 Snap 专用宿主运行时目录。
- Arch Linux 容器中的 quick-sharun 收集主程序及 `keytar.node` 所需的 `libsecret`，生成 AppImage。入口保留官方 Snap 使用的 `--no-sandbox` 参数，桌面图标与 desktop 文件来自同一 Snap。
- 将 ICU、PAK、`locales` 和 `resources` 以包内链接接到启动包装器旁，保持 Electron 按可执行文件目录查找资源的行为。
- TradingView 自带 Chromium；AppImage 不要求宿主机另装 Chromium。构建环境安装 IBus 和 Fcitx5 的 GTK3 输入模块，由现有 `DEPLOY_GTK=1` 收集进包；启动入口保留宿主输入法环境。官方说明 Snap 版在原生 Wayland 下可能不稳定，当前入口使用 X11。

## 运行

在 Linux 终端中，下载 Release 资产并赋予执行权限后运行：

```bash
# 启动已赋予执行权限的 TradingView AppImage
./tradingview.AppImage
```

## 版本元数据

成功生成 AppImage 后，把本次 Snap Store 稳定版的实际版本写入 `tradingview/dist/version.txt`，供正式工作流更新软件版本清单。

## 维护说明

TradingView 为专有软件，使用和再分发应遵守其许可条款。构建脚本不固定应用或打包工具版本。GUI 启动和图表加载已有 Linux 实机截图；登录仍需单独核对。

## 2026-09-23：中文输入修复待实机验证

Linux 实机反馈观点编辑框只能输入英文。检查此前 AppImage 的 GTK3 输入模块目录，未找到 `im-ibus.so` 和 `im-fcitx5.so`。本次仅在 `build_tradingview.sh` 的应用级依赖加入 `ibus` 与 `fcitx5-gtk`，保留已能启动并加载图表的 Electron 入口；新产物中文输入尚待实机验证。
