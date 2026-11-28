# 腾讯会议模板差异

构建阶段沿用 [Qt DEB linuxdeploy 模板](../../Templates/appimage/linuxdeploy-qt-deb.sh)风格。以下步骤依照腾讯会议的官网下载方式和已实机确认的 Qt5 布局。

| 阶段 | 处理 | 依据与影响 |
| --- | --- | --- |
| 下载并准备应用 | 使用公共 JSON 入口核对官网下载地址、文件名、版本、包名和架构，后续安装与解包使用该 DEB。 | 保留官网动态版本、x86_64 资产和原始 `opt/wemeet` 布局。 |
| 准备桌面资源和运行库 | 核对包内主程序可执行，将原图标安装为 `wemeet.png`，修改 desktop 的 `Exec` 和 `Icon`。 | 自定义 AppRun 直接执行 `opt/wemeet/bin/wemeetapp`。图标安装和 desktop 编辑命令分别处理自身的输入错误。 |
| 准备桌面资源和运行库 | 调用公共入口生成包内 `zh_CN.UTF-8`。 | AppRun 通过 `LOCPATH` 使用包内 locale，并为不能读取它的宿主提供 UTF-8 与中文语言回退。 |
| 准备 AppRun | 保留官方库和 Qt 插件的优先顺序、Wayland 回退、时区和参数转发。 | 旧产物由 Qt 插件生成包装层，留存的 `AppRun.wrapped` 执行行与本次草稿一致。 |
| 核心打包 | 指定真实 Qt5 qmake，沿用精确的 Xtst、PulseAudio、配套库和官方 Qt5Gui 部署参数。 | Qt 插件依靠 `usr/lib` 下的 QtGui 识别模块。PulseAudio 相关库对应旧版实机缺库记录。 |

具体参数见[固定配置](./hardcoded.md)。pkgforge-dev 的 quick-sharun、额外 hook 和 AUR 路径未启用，见[上游打包差异](./pkgforge-differences.md)。实机结果见[应用 README](../README.md#2026-09-24实机确认最新成品能开会)。
