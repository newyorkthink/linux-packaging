# linuxdeploy 项目清单与打包规范

本文件同时承担两项职责：

1. 记录当前仓库中**构建脚本实际调用 `linuxdeploy`** 的项目；
2. 规定以后新增、迁移或重做 linuxdeploy 项目时必须遵守的共同流程。

仅在 README、注释或说明文字中出现 `linuxdeploy`，但构建脚本没有实际调用的项目，不计入本清单。已经验证稳定的现有项目继续以自身 README 和脚本为稳定基线；本规范用于后续工作，不得为了套模板而顺手重写稳定项目。

## 当前项目清单

| 项目 | 构建脚本 | 使用方式 |
| --- | --- | --- |
| Alacritty | `alacritty/build_alacritty_linuxdeploy.sh` | linuxdeploy |
| MediaInfo | `mediainfo/build_mediainfo_linuxdeploy.sh` | linuxdeploy |
| PeaZip | `peazip/build_peazip.sh` | linuxdeploy + Qt 插件 |
| XnConvert | `xnconvert/build_xnconvert.sh` | linuxdeploy + Qt 插件 |
| Joplin | `joplin/build_joplin.sh` | linuxdeploy + GTK 插件 |
| XnView MP | `xnviewmp/build_xnviewmp.sh` | linuxdeploy + Qt 插件 |
| Poppler Utils | `poppler-utils/build_poppler-utils.sh` | linuxdeploy |
| Remmina | `remmina/build_remmina.sh` | linuxdeploy + GTK / GStreamer 插件 |
| dconf Editor | `dconf-editor/build_dconf-editor.sh` | linuxdeploy |
| 百度网盘 | `baidunetdisk/build_baidunetdisk.sh` | linuxdeploy + GTK 插件 |
| Rainlendar2 | `rainlendar2/build_rainlendar2.sh` | linuxdeploy + GTK 插件 |
| RealVNC RVNC Connect | `realvnc-rvnc-connect/build_realvnc-rvnc-connect.sh` | linuxdeploy + GTK 插件 |

部分项目使用 linuxdeploy 负责整理 AppDir、收集依赖或调用输入插件，最终 AppImage 由 appimagetool 单独封装；本清单的判断标准是构建流程中是否实际调用 linuxdeploy。

## 新项目必须先横向参考现有实现

开始新增、迁移或重做 linuxdeploy 项目前，必须先完整阅读根目录 `AGENTS.md`、本文件、目标应用 README、构建脚本和对应 workflow，再从本仓库选择至少 2～3 个技术栈与上游包布局最接近的项目横向核对。

参考优先级：

| 当前项目类型 | 优先参考 |
| --- | --- |
| 普通 ELF / CLI，无 Qt、GTK 输入插件 | MediaInfo、Poppler Utils、Alacritty |
| Qt 应用 | PeaZip、XnConvert、XnView MP |
| GTK 应用 | Joplin、百度网盘、Rainlendar2、RealVNC RVNC Connect |
| GTK + GStreamer / 多插件应用 | Remmina，并同时参考一个普通 GTK 项目 |
| GSettings、dconf、locale 或多入口较复杂 | dconf Editor、Poppler Utils，并结合相同技术栈项目 |

横向参考的目的是比较上游来源、AppDir 布局、主程序入口、desktop / icon、AppRun、插件、动态加载依赖、appimagetool 和 runtime 处理，不是复制整段脚本。不得把另一个项目的 Qt、GTK、GStreamer、主题、输入法、多媒体或兼容变量无条件搬入当前项目。

## 标准打包顺序

新增或重做的 linuxdeploy 项目默认按以下顺序完成：

1. 使用 Ubuntu 环境准备最小构建工具和当前应用真实需要的依赖；默认基线见 `AGENTS.md`。
2. 动态取得当前官方 linuxdeploy、实际需要的输入插件、官方 appimagetool 和明确的 Type 2 runtime。
3. 准备 AppDir，放入真实主程序、desktop、icon、应用资源及已经确认需要显式带入的动态加载依赖。
4. **在调用 linuxdeploy 前，先创建当前项目自己的根目录 `AppDir/AppRun`，并赋予执行权限。**
5. 根据实际技术栈选择输入插件：Qt 才使用 `--plugin qt`，GTK 才使用 `--plugin gtk`，确实需要 GStreamer 才使用 `--plugin gstreamer`；普通 ELF 不添加框架插件。
6. linuxdeploy 只负责整理 AppDir、部署普通 ELF 依赖和所选输入插件，不使用 `--output appimage` 生成最终发布产物。
7. linuxdeploy 完成后核对最终 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks` 的实际执行链。
8. 使用官方 appimagetool 和明确的 runtime 单独封装最终 AppImage。
9. 按当前修改风险完成必要检查，核对完整 diff 后一次提交；临时测试脚本、日志、解包目录和测试专用代码不得进入正式提交。
10. 同步更新当前应用 README；新增 linuxdeploy 项目时同时更新本文件的项目清单。

不得为了让构建通过而跳过 AppRun 设计、预防性启用全部插件、固定旧打包工具、把 linuxdeploy 输出插件当最终封装器，或通过多次提交和反复触发 Actions 试错。

## AppRun 默认规则

### 默认先创建真实 AppRun

新项目默认在 linuxdeploy 运行前写入真实的 `AppDir/AppRun`。它必须是普通可执行文件，明确设置当前应用真正需要的运行路径，最后使用 `exec` 启动真实主程序并原样传递 `"$@"`。

基础结构只保留当前应用需要的内容，例如：

```bash
#!/bin/sh

HERE="$(CDPATH= cd -P -- "$(dirname -- "$0")" && pwd)"

export PATH="$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

exec "$HERE/usr/bin/<真实主程序>" "$@"
```

示例中的主程序和目录必须替换为当前 AppDir 的真实路径。不使用的目录不得为了“模板完整”加入搜索路径；上游程序位于 `opt/<应用>`、需要特定工作目录、包含多个入口或需要保留宿主变量时，必须按当前应用实际布局调整。

### Qt、GTK 和 GStreamer 内容按需追加

- **Qt 应用：** 先确认主程序实际使用 Qt 5 还是 Qt 6，再启用 `--plugin qt`。只有最终 AppDir 的真实 Qt plugin / QML 路径或已确认运行需求需要时，才在 AppRun 中加入 `QT_PLUGIN_PATH`、`QT_QPA_PLATFORM_PLUGIN_PATH`、`QML_IMPORT_PATH`、`QML2_IMPORT_PATH`、`QT_QPA_PLATFORM`、`QT_QPA_PLATFORMTHEME` 等变量。
- **GTK 应用：** 只在应用确实为 GTK 且需要 GTK 输入插件部署时启用 `--plugin gtk`。基础 AppRun 可以保留 `XDG_DATA_DIRS` 和应用实际需要的 `GSETTINGS_SCHEMA_DIR`；`GTK_PATH`、`GTK_THEME`、输入法和 pixbuf / immodules 变量应优先由 GTK hook 管理，只有已有证据表明需要覆盖或补充时才写入自定义 AppRun。
- **GStreamer 应用：** 只有程序确实依赖 GStreamer plugin，且普通 ELF 收集不能完整部署运行时模块时，才启用 `--plugin gstreamer` 并添加对应搜索路径。
- **普通 ELF / CLI：** 不得因为其他项目使用了 Qt、GTK 或 GStreamer 插件，就照抄相应插件和环境变量。

`QT_AUTO_SCREEN_SCALE_FACTOR`、`QT_SCALE_FACTOR`、`QT_STYLE_OVERRIDE`、`QT_QPA_PLATFORMTHEME`、`QT_QPA_PLATFORM`、`QT_FONT_DPI`、`GTK_THEME`、`NO_AT_BRIDGE` 等都属于可能影响显示、主题、缩放、辅助功能或后端选择的项目级配置，**不是 linuxdeploy 通用 AppRun 模板**。只有当前应用的稳定基线、上游要求、已有日志或真实运行反馈证明需要时才可加入。

### 正确保留 AppRun hook 执行链

Qt、GTK、GStreamer 等输入插件可能在 `AppDir/apprun-hooks/` 安装 hook。linuxdeploy 发现非空 hook 后，可能把预先创建的自定义 AppRun 保存为 `AppRun.wrapped`，再生成新的顶层 `AppRun` 负责加载 hook 并执行 `AppRun.wrapped`。

因此：

- 必须先创建自定义 `AppDir/AppRun`，再运行 linuxdeploy。
- 不得手工创建、编辑或把业务逻辑直接写进 `AppRun.wrapped`。
- linuxdeploy 完成后，不得无依据覆盖它生成的顶层 `AppRun`，否则可能绕过 Qt / GTK / GStreamer hook。
- 最终必须确认顶层 `AppRun` 能加载实际存在的 hook，并正确执行保存下来的自定义入口。
- 如果某个已经验证稳定的历史项目因明确兼容原因使用 `--custom-apprun`、在 linuxdeploy 后恢复最终 AppRun，或主动移除 `AppRun.wrapped`，继续以该项目 README 和现有脚本为稳定基线；新项目不得无证据复制这种例外。

## linuxdeploy 与 appimagetool 的职责边界

标准调用结构如下，实际路径和插件按项目填写：

```bash
# linuxdeploy 只整理 AppDir 并部署依赖；无框架插件时删除 --plugin 参数
export ARCH=x86_64
linuxdeploy --appdir <AppDir路径> --plugin <qt|gtk|gstreamer>

# appimagetool 使用明确的 runtime 生成最终 AppImage
export ARCH=x86_64
appimagetool -n <AppDir路径> <输出AppImage> --runtime-file <runtime文件>
```

强制要求：

- linuxdeploy 命令不得使用 `--output appimage` 作为最终发布步骤。
- 输入插件只按技术栈启用，不得一次下载或启用全部插件。
- linuxdeploy、输入插件、appimagetool 和 runtime 必须来自各自官方动态入口，不得为了恢复旧行为固定旧版本、旧提交或旧资产。
- 网络下载失败应让当前构建明确失败或按既有下载重试逻辑处理，不得自动回退到旧工具、旧 runtime 或另一套打包路线。
- linuxdeploy 自动收集不到的 `dlopen` plugin、provider、翻译、helper、数据文件或特殊目录，只能根据源码、ELF、已有日志、已有产物或真实运行反馈补入最小集合。
- 最终产物名、desktop、icon、主程序入口和 workflow 接入必须与当前项目 README 及仓库清单一致。

## 检查要求

AI 可以在本地、容器或临时目录执行与当前修改直接相关的语法检查、静态分析、试构建、试打包、AppImage 解包、`ldd`、启动或功能验证。

检查重点：

- `AppRun` 是普通可执行文件，主程序路径、引号和 `"$@"` 传参正确；
- 插件与应用技术栈一致，Qt 5 / Qt 6 没有混用；
- 最终 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks` 执行链正确；
- desktop、icon、主程序、动态加载模块和最终 AppImage 资产名正确；
- linuxdeploy 未承担最终 AppImage 封装，appimagetool 使用了明确 runtime；
- workflow 只触发当前项目所需构建，没有新增临时 test workflow、测试 Job 或测试 Step；
- 完整 diff 没有测试脚本、临时日志、解包目录、缓存、测试专用断言或无关改动。

不能完成的构建或运行检查必须明确标记为未验证，不得把静态检查通过描述为实机运行通过，也不得为了验证而把一堆 test / smoke 代码写入正式构建脚本。

## 不计入的已核对项目

- `htop/build_htop.sh`：明确使用 quick-sharun，不使用 linuxdeploy。
- `goldendict-ng/build_goldendict-ng.sh`：只有注释提到 linuxdeploy，构建脚本没有实际调用 linuxdeploy。
