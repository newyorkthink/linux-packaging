# XnView MP 专属差异

本目录是 Qt 类型标准参考。公共流程和 Qt 通用注释按 [linuxdeploy 规范](../../linuxdeploy_projects.md) 与 [固定注释标准](../../docs/linuxdeploy-comments.md) 执行；以下处理只适用于当前应用。

| 位置 | 专属处理及原因 | 代码或依据 |
| --- | --- | --- |
| 安装包 | 官网提供校验清单，使用公共 DEB 入口的 `--checksum` 模式，不套用 GitHub Release 来源。 | [安装包准备](../build_xnviewmp.sh#L32) |
| 桌面资源 | 官方 desktop 使用绝对图标路径，公共封装检查不接受；改为图标名称，并保留 `--icon-file` 的包内 PNG 参数。 | [图标处理](../build_xnviewmp.sh#L39) |
| Qt 模块识别 | Qt 库位于 `opt/XnView/lib`，保留自带 XCB 平台库的复制，供插件识别模块。 | [复制位置](../build_xnviewmp.sh#L46)；[原始失败日志](https://github.com/newyorkthink/linux-packaging/actions/runs/41175873664/job/124463228278) |
| 媒体运行库 | 包内组件需要 PulseAudio / Wayland；Qt 还会动态加载 PipeWire / VA-API。按现有精确列表收集，并保留 libpulsecommon 配套库。 | [运行库收集](../build_xnviewmp.sh#L49)；原因及日志见 [README](../README.md#变更记录) |
| qmake6 | 独立入口在启动系统工具前清除 LD_LIBRARY_PATH，避免应用自带 Qt 干扰系统 qmake。 | [工具入口](../build_xnviewmp.sh#L110)；历史故障见 README |
| 中文 locale | 本程序已有中文翻译及中文界面需求，资源阶段生成包内 locale；AppRun 先设置 `LOCPATH` 再沿用原 `LANG`、`LANGUAGE`。不替换翻译或输入模块。 | [公共生成调用](../build_xnviewmp.sh#L37)；[适用范围](../README.md#包内中文-locale-与界面翻译) |
| AppRun | 保留已确认的 Qt / QML / 翻译路径、中文环境、缩放、字体、IBus Portal 和视频设置；路径已固化，不增加构建阶段 LD_LIBRARY_PATH 或路径整理调用。 | [完整 AppRun](../build_xnviewmp.sh#L61) |

## 专属注释原文

以下注释随上述处理保留，不加入公共注释表：

### 桌面资源

- `# 指定 XnView MP 官方安装包中的桌面入口和图标路径，供图标修正及 linuxdeploy 图标部署使用。`
- `# XnView MP 官方桌面入口使用绝对图标路径，需改为图标名称才能通过公共封装检查。`

### Qt 模块识别

- `# 复制应用自带的 Qt XCB 平台库，供 Qt 插件识别模块。`

### 媒体运行库

- `# XnView MP 的包内组件依赖 PulseAudio、Wayland，Qt 多媒体还会动态加载 PipeWire 和 VA-API，因此一并补入对应运行库。`
- `# 复制当前运行库及其版本文件。`
- `# 为 XnView MP 补入的 PulseAudio 库还依赖 libpulsecommon，因此同时复制该配套库。`

### qmake6 入口

- `# 创建独立的 Qt 查询工具入口，避免应用自带运行库影响系统工具。`
- `# 清除运行库搜索路径。`
- `# 启动系统工具，并保留传入的命令行参数。`
- `# 为工具入口添加执行权限。`

### 输入法

- `# 使用 XCB 后端，并通过包内 IBus 插件和 IBus Portal 接入 Fcitx5。`

路径和固定参数的既有取值见 [hardcoded.md](./hardcoded.md)，故障与实测历史见 [README](../README.md)。视频黑屏和 QMutex 的未解决记录保持原样，不把保留的视频设置写成已经修复。

2026-11-02 核对上游打包参考索引及 pkgforge-dev 的 xnview / XnView MP 名称，未找到对应打包仓库；本次仅复用本仓库已有 locale 公共入口，不引入外部应用专属代码。
