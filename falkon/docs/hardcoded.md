# Falkon 固定配置

本页记录当前构建和运行时 hook 中的固定路径、包名及默认环境取值，说明来源、用途和原始报错依据。软件版本仍由公共入口从当次安装的 Arch 软件包动态读取，不固定 Falkon 或打包工具版本；相对标准模板的结构差异见 [template-deviations.md](./template-deviations.md)。

## 固定配置清单

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 程序来源与入口 | Arch 官方 `falkon` 包，`/usr/bin/falkon` | [Arch Extra 软件包](https://archlinux.org/packages/extra/x86_64/falkon/) 提供原生二进制入口，沿用系统入口收集路线；[构建位置](../build_falkon.sh#L13)、[收集位置](../build_falkon.sh#L36)。 |
| 图标与桌面入口 | `/usr/share/icons/hicolor/256x256/apps/falkon.png`、`/usr/share/applications/org.kde.falkon.desktop` | Arch `falkon` 官方包自带的桌面资源，直接交给 quick-sharun；[构建位置](../build_falkon.sh#L22-L24)。 |
| 产物与版本文件 | `dist/falkon.AppImage`、`dist/version.txt` | 沿用 `.github/appimage-apps.json` 中的 `falkon` 资产名与版本清单接口；[构建位置](../build_falkon.sh#L26-L28)、[保存位置](../build_falkon.sh#L89)。 |
| 深色图标包与目录 | `breeze-icons`、`/usr/share/icons/breeze-dark` → `AppDir/share/icons/breeze-dark` | Arch 官方 `breeze-icons` 提供深色图标目录，随包携带供深色外观和已配置该图标主题的环境使用；[安装位置](../build_falkon.sh#L13)、[复制位置](../build_falkon.sh#L38-L40)。 |
| 内置深色主题 | 基于 `/usr/share/falkon/themes/linux` 生成 `dark-slate`、`oled-black`，覆盖层位于 `falkon/resources/themes/` | 复制当次安装的官方 `linux` 主题保留布局、图标属性和资源，再覆盖 `metadata.desktop` 并追加深色 QSS，供未配置 `qt6ct` 的环境在外观设置中切换；[构建位置](../build_falkon.sh#L42-L51)。 |
| 语言环境策略 | 不生成包内 `zh_CN.utf8`，不写入 `AppDir/.env` 语言变量，保留 `fcitx5-qt` | 避免固定中文 locale 导致 `Accept-Language`、`navigator.language`、`Intl` 等区域特征与宿主机或海外网络环境冲突，防止注册或访问地区敏感站点时触发误判；同时保留中文输入法。 |
| 默认 Qt 平台主题 | `QT_QPA_PLATFORMTHEME=qt6ct`（仅外部未设置时） | 包内已随 `qt6ct` 打入平台主题插件，但未设置该变量时 Falkon 外框不会读取用户的 `qt6ct` 深色调色板；在启动 hook 中设为默认值，外部显式指定其他平台主题时保持外部值；[hook 位置](../build_falkon.sh#L58-L61)。 |
| `root` 沙箱兜底 | `QTWEBENGINE_DISABLE_SANDBOX=1`（仅 `id -u` 为 `0` 且外部未定义时） | 解决远程桌面等环境中以 `root` 启动时 Chromium Zygote 拒绝无沙箱启动的问题；普通用户不触发，外部显式定义该变量时不覆盖；[hook 位置](../build_falkon.sh#L63-L67)。 |
| 无 GPU 软件渲染兜底 | `QTWEBENGINE_CHROMIUM_FLAGS='--disable-gpu --use-gl=disabled'`（仅无可读可写 `/dev/dri/renderD*` 且外部未定义时） | 解决无显卡远程桌面环境中 GLX/DRI3/GBM 渲染节点初始化失败的问题；存在可用渲染节点的桌面环境不触发，外部显式定义该变量时不覆盖；[hook 位置](../build_falkon.sh#L69-L79)。 |

## 远程桌面原始报错记录

以下为无 GPU 远程桌面环境中以 `root` 直接启动 Falkon 时复现的脱敏终端原始输出（已去除主机名与个人环境提示符），分别对应 `QTWEBENGINE_CHROMIUM_FLAGS` 与 `QTWEBENGINE_DISABLE_SANDBOX` 两项条件兜底的依据：

```text
> falkon
qt.qpa.xcb: failed to initialize XRandr 1.2
qt.qpa.xcb: X server does not support XInput 2
There is no XRandr 1.2 and later version available. There will be only fake screen(s) to use.
qt.qpa.gl: QXcbConnection: Failed to initialize GLX
MESA-EGL: warning: DRI3 error: Could not get DRI3 device
MESA-EGL: warning: Ensure your X server supports DRI3 to get accelerated rendering
EGL: Failed to query DRM render node file path. Fallback to /dev/dri/renderD128.
GBM: Failed to initialize DRM render node handle: /dev/dri/renderD128

GBM: Obtained an invalid file descriptor.
[4179163:4179163:1126/192545.423728:ERROR:../../qtwebengine/src/3rdparty/chromium/content/browser/zygote_host/zygote_host_impl_linux.cc:105] Running as root without --no-sandbox is not supported. See https://crbug.com/638180.
```

实机通过记录见 [README 实机验证](../README.md#实机验证)。
