# mpv AppImage

## 用途与产物

本目录将 Arch 当前 mpv 打包为 `mpv.AppImage`，并保留 yt-dlp 与双击无参数时的伪 GUI 启动行为。

## 技术栈与打包方式

mpv 为原生 C 媒体播放器，使用 [Arch 官方仓库的 mpv 二进制包](https://archlinux.org/packages/extra/x86_64/mpv/)，当前正式构建为 x86_64。采用 [Arch 官方仓库原生程序系统入口标准](../anylinux_projects.md#arch-官方仓库原生程序系统入口标准)；本目录不编译 mpv，也不预先复制主程序到 AppDir/bin。

1. 公共入口安装统一基础包，以及 mpv、mpv-mpris、glycin、libheif 和原有 Xorg 依赖；原脚本的依赖均保留。
2. 图标和 desktop 读取已安装包的系统路径，直接执行 `quick-sharun /usr/bin/mpv` 收集程序及依赖。
3. 原样采用 pkgforge-dev 的 `echo 'LC_ALL=C.UTF-8' >> ./AppDir/.env`。官方注释说明 mpv 只支持 C / C.UTF-8 数值 locale，不能依赖 anylinux.so 改成其他值。本次不再执行旧 `LC_ALL=` / `LC_NUMERIC=C` 两行，也不生成中文 locale 或额外部署 GTK / Qt 输入模块。
4. 保留本仓库在依赖收集后下载独立 yt-dlp 的方式：公共入口从 `yt-dlp/yt-dlp` 当前正式 Release 选择 `yt-dlp_linux`，校验 GitHub SHA-256，内置到 `AppDir/usr/bin/yt-dlp`。
5. 将独立保存的官方无参数窗口 hook 复制到 AppDir；未传入参数时补 `--player-operation-mode=pseudo-gui`，有参数时不改参数。quick-sharun 生成 AppRun，本目录不自写启动 wrapper。
6. 最后执行 `quick-sharun --make-appimage`，输出 `dist/mpv.AppImage`。

locale 和窗口 hook 来源为 [pkgforge-dev/mpv-AppImage 的固定源码](https://github.com/pkgforge-dev/mpv-AppImage/tree/953226d87422e9ef2307afacd2e049b1ee0a7f56)。窗口 hook 的官方注释明确说明双击时没有参数，否则不会打开 GUI；可执行代码原样保留，注释采用统一中文说明。

**yt-dlp 使用我们自己的构建时内置方式。** 未启用官方 `ADD_HOOKS="self-updater.hook:get-yt-dlp.hook"`：官方 get-yt-dlp hook 会在运行时缺少 yt-dlp 时询问，再下载 pkgforge-dev 的 yt-dlp AppImage 到用户程序目录；self-updater hook 另行询问并更新 AppImage。当前构建不接入这两项运行时流程，也不设置官方 UPINFO、实验性宿主驱动和 runtime preload 开关。mpv 和内置 yt-dlp 随本仓库下一次构建更新。

## 版本元数据

第一次 quick-sharun 之前，用 `common/build/read_app_version.sh pacman mpv` 读取本次实际安装的 mpv 版本，去掉 Arch epoch 与 pkgrel。最终 AppImage 成功生成后，单行调用 `common/build/save_appimage_version.sh` 写入 `dist/version.txt`；yt-dlp 的版本不替代 mpv 版本。

现有 [Build AppImages](../.github/workflows/build.yml) 通过 [应用清单](../.github/appimage-apps.json) 的标准 Arch matrix 执行本目录脚本，产物名保持 `mpv.AppImage`，`SOFTWARE_KEY=mpv` 保持不变。构建发布成功后由该 Job 立即更新自己的版本清单条目。

## 运行

```bash
./mpv.AppImage
```

## 维护说明与验证范围

| 文档 | 用途 |
| --- | --- |
| [固定配置依据](./docs/hardcoded.md) | 说明路径、软件包、资产名、locale 和固定参数为什么这样写，保留旧注释依据。 |
| [模板差异](./docs/template-deviations.md) | 说明原生系统入口基础模板之外实际启用的三个专属段及其阶段。 |
| [pkgforge 取舍](./docs/pkgforge-differences.md) | 保存官方原文、用途、原因、采用项及未启用项；后续拟加入时先核实当前官方是否仍保留且适用。 |

本次完成 Shell 语法、依赖覆盖、模板结构与文档引用的静态检查；未在本次任务执行正式打包或实机运行。不得把静态检查写成播放、MPRIS、在线解析、中文输入或跨发行版运行已经通过。mpv-mpris 继续安装，不据此宣称其脚本已在最终产物加载。固定 `LC_ALL=C.UTF-8` 会覆盖宿主 locale，本次不承诺保留宿主中文语言设置。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据输出，不改变现有 mpv、yt-dlp、locale 或 GUI hook 行为。

### 2026-10-30：按原生系统入口标准整理

按本次确认的 52 行脚本统一严格模式、注释、空行、系统入口和公共版本接口；所有原有依赖由基础包或应用安装行继续覆盖。yt-dlp 保留构建时内置，下载改用公共入口动态选择正式资产并校验摘要；不采用官方运行时安装 yt-dlp 和自更新 hooks。

旧 locale 两行已被本次明确批准的官方 `LC_ALL=C.UTF-8` 替代；旧脚本曾说明用于处理 `Non-C locale detected` 并保留 LANG，但没有提供原始运行日志，不将其扩写成已复现故障。旧注释及代码完整保存在 [固定配置依据](./docs/hardcoded.md#旧实现原始记录)。窗口 hook 从内联 heredoc 改为独立文件，保留官方可执行内容。同步补齐分类、标准与三份应用 docs；本次只确认上述静态检查，正式构建及实机运行结果未在本次核实。
