# Joplin 专属差异

本目录是 GTK 类型标准参考。这里只记 Joplin 的实际取值和处理原因，不作为所有 GTK 程序的固定配置；流程与公共注释见 [linuxdeploy 规范](../../linuxdeploy_projects.md) 和 [固定注释标准](../../docs/linuxdeploy-comments.md)。

| 位置 | 处理及原因 | 代码或依据 |
| --- | --- | --- |
| 应用来源 | 从官方 GitHub 正式 Release 取得 x64 DEB；同一份校验后的包用于安装和解包。 | [安装包准备](../build_joplin.sh#L32) |
| 依赖与布局 | 保留 Electron / GTK3、IBus、GIO 和 NSS 依赖；应用主体保持官方 `opt/Joplin` 布局。 | [依赖安装](../build_joplin.sh#L17) |
| 图标与主题 | 补入 Adwaita 图标和主题资源，供已确认的深色主题使用。 | [资源准备](../build_joplin.sh#L40) |
| NSS | 核心库与动态加载模块使用同一构建环境的配套版本，避免混用宿主 NSS。 | [NSS 公共入口](../build_joplin.sh#L43) |
| 中文 locale | 按用户要求在资源准备阶段调用公共入口生成包内 locale；AppRun 先指定包内 locale 目录，再设置中文语言和消息环境。 | [locale 生成](../build_joplin.sh#L37)、[AppRun 中文配置](../build_joplin.sh#L58)；[范围与验证](../README.md#包内中文-locale) |
| AppRun | 直接启动 `opt/Joplin/joplin`；保留 GTK schema、GIO、Adwaita 深色主题及辅助功能兼容配置。 | [完整 AppRun](../build_joplin.sh#L48) |
| 构建环境 | 保留已确认的 Ubuntu 22.04 runner，不因其他参考使用 Ubuntu 24.04 而改动。 | [README 构建环境](../README.md#构建环境与依赖) |

本脚本的通用注释直接复用公共表，无需另列专属注释。深色主题、中文输入及 AppRun 的既有实测结论和故障历史保留在 [README](../README.md)。

本次核对 [pkgforge-dev/Joplin-Desktop-AppImage 的 make-appimage.sh](https://github.com/pkgforge-dev/Joplin-Desktop-AppImage/blob/8fbdda883b6d276938d7b67a237032e0282a7252/make-appimage.sh) 及其依赖脚本、workflow 和 README；该仓库使用 quick-sharun，没有应用级中文 locale 生成段。本次没有移植其封装命令或 hooks，继续使用本仓库既有 linuxdeploy 路线和独立 locale 公共入口。
