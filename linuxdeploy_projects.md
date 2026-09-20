# linuxdeploy 项目清单与打包规范

本文件记录当前仓库实际调用 `linuxdeploy` 的项目，并规定以后新增、迁移或重做 linuxdeploy 项目的统一流程。

本规范基于以下证据整理：

- 当前仓库全部 linuxdeploy 构建脚本；
- 用户本地已经实际使用的两阶段命令；
- 用户提供的 PeaZip 与 File Roller AppImage 解包结果；
- linuxdeploy、linuxdeploy-plugin-qt、linuxdeploy-plugin-gtk 和 Type 2 runtime 的实际行为。

两个样本解包后都确认存在顶层 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks/`。PeaZip 顶层 AppRun 自动加载 `linuxdeploy-plugin-qt-hook.sh`，File Roller 顶层 AppRun 自动加载 `linuxdeploy-plugin-gtk.sh`，随后执行 `AppRun.wrapped`。这证明第二次 linuxdeploy 必须保留 `--output appimage`，让输出阶段完成 hook 与 AppRun 包装。

已经验证稳定的现有项目继续以自身 README 和脚本为稳定基线；不得为了套用本文模板而顺手重写稳定项目。

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

仅在 README、注释或说明文字中出现 linuxdeploy，但构建脚本没有实际调用的项目，不计入本清单。

## 新项目必须先横向参考现有实现

开始新增、迁移或重做 linuxdeploy 项目前，必须先完整阅读根目录 `AGENTS.md`、本文件、目标应用 README、构建脚本和对应 workflow，再从本仓库选择至少 2～3 个技术栈与上游包布局最接近的项目横向核对。

| 当前项目类型 | 优先参考 |
| --- | --- |
| 普通 ELF / CLI | MediaInfo、Poppler Utils、Alacritty |
| Qt 应用 | PeaZip、XnConvert、XnView MP |
| GTK 应用 | Joplin、百度网盘、Rainlendar2、RealVNC RVNC Connect |
| GTK + GStreamer / 多插件应用 | Remmina，并同时参考一个普通 GTK 项目 |
| GSettings、dconf、locale 或多入口应用 | dconf Editor、Poppler Utils，并结合相同技术栈项目 |

横向参考只用于比较上游来源、AppDir 布局、AppRun、desktop / icon、插件和动态加载依赖。不得复制另一个项目的整段 Qt、GTK、GStreamer、主题、输入法、多媒体或特殊兼容逻辑。

## 唯一标准流程：linuxdeploy 中间输出，再由 appimagetool 最终封装

### linuxdeploy 命令形式固定，不随上游安装目录改变

无论上游 DEB、归档或安装结果把真实程序放在 `/opt`、`/usr/bin` 还是其他目录，先按上游真实布局准备 AppDir；linuxdeploy 本身统一只使用下面三种基础命令：

```bash
# 普通应用统一使用此命令
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage

# GTK 应用统一使用此命令
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

# Qt 应用统一使用此命令
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

项目确有需要时，只允许在对应基础命令上追加以下三类参数：

- `--desktop-file <desktop 文件>`；
- `--icon-file <图标文件>`；
- `-l <已核实的单个库路径>`，需要多个库时逐个追加 `-l`。

**禁止追加 `--executable`。** 该参数可能把原本位于 `AppDir/opt/<应用>/` 的真实主程序再次部署到 `AppDir/usr/bin/`，制造不属于上游包布局的副本。也禁止擅自加入上述允许范围之外的其他 linuxdeploy 参数。应用真实入口统一由根 `AppDir/AppRun` 按实际布局直接执行，不通过 linuxdeploy 命令行改变上游目录结构。

### 第一步：普通 linuxdeploy 创建并整理 AppDir

先执行用户本地已经验证的原命令：

```bash
# 创建并整理 AppDir，同时生成 linuxdeploy 中间 AppImage
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage
```

这一步由 linuxdeploy 创建 / 整理 AppDir 的 `usr/bin`、`usr/lib`、`usr/share`、desktop、icon、根目录链接及其他能够从现有输入识别的结构。linuxdeploy 自动创建某个目录只表示基础结构存在，不表示该目录必须有文件；例如 `AppDir/usr/bin/` 可以保持为空。应用本体必须提前按上游真实布局放入 AppDir；desktop 和 icon 可按需通过允许的 `--desktop-file`、`--icon-file` 传入。不得使用 `--executable` 把 `/opt` 中的程序再次部署到 `usr/bin`，也不得为了填满自动创建的目录而改变上游真实布局。

这一步生成的 AppImage 只是中间产物，不进入发布目录。

### 第二步：所有 linuxdeploy 项目统一写入根 AppDir/AppRun

**任何使用 linuxdeploy 的项目，自定义启动入口都必须写在 AppDir 根目录的 `AppDir/AppRun`。这是固定路径，不因普通、Qt、GTK 或 GStreamer 技术栈而改变。**

第一次 linuxdeploy 完成后，如根目录已经存在 linuxdeploy 默认创建的 `AppRun` 或指向 `usr/bin` 的链接，应先删除或替换它；随后把当前项目完整的启动环境、必要工作目录和最终执行命令直接写入 `AppDir/AppRun`，并赋予执行权限。这个根 `AppDir/AppRun` 必须使用当前 AppDir 的真实路径，最后直接执行真正主程序并原样传递 `"$@"`。

禁止把项目自定义启动逻辑写进新建的 `AppDir/usr/bin/<程序名>`、其他 wrapper 或 launcher，再把根 `AppDir/AppRun` 写成只负责调用它的二次转发壳。特别是 `PATH`、`LD_LIBRARY_PATH`、`QT_PLUGIN_PATH`、`XDG_DATA_DIRS`、Qt / GTK 兼容变量和最终 `exec`，都应按当前应用实际需要直接位于根 `AppDir/AppRun`。

**`AppDir/usr/bin/` 可以为空，而且空目录不需要处理。** 第一次 linuxdeploy 可能自动创建该目录；这只是工具生成的基础结构，不表示主程序必须放在这里。上游 DEB 或归档如果把应用全部放在 `/opt/<应用>/`，就保持 `AppDir/opt/<应用>/` 的真实布局，不复制到 `usr/bin`，不为填充目录创建自制 wrapper，也不增加没有实际需要的符号链接。

`AppDir/usr/bin/` 只有在上游包真实提供对应内容或应用确有必要入口时，才保留以下内容：

- 应用自身原本位于该处的真实可执行文件；
- 当前应用确实需要的符号链接；
- 上游包原本提供且运行确实需要的 launcher。

即使当前应用必须保留上游 `usr/bin` launcher，linuxdeploy 项目的自定义入口仍然是根 `AppDir/AppRun`，不得用 `usr/bin` launcher 取代它。第二次 linuxdeploy 产生 hook 时，应由 linuxdeploy 自动把这个根 `AppDir/AppRun` 保存成 `AppRun.wrapped`。

根 AppRun 必须按上游真实布局直接执行主程序。`/opt` 布局示例：

```bash
#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"

export LD_LIBRARY_PATH="$HERE/opt/<应用>/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

exec "$HERE/opt/<应用>/<真实主程序>" "$@"
```

只有主程序真实位于 `AppDir/usr/bin/` 时，才使用对应入口：

```bash
#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"

export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

exec "$HERE/usr/bin/<真实主程序>" "$@"
```

不得把截图或其他项目中的全部目录和变量机械复制过来。Qt、GTK、主题、缩放、输入法和工作目录设置只按当前应用实际需要追加。

### 第三步：按技术栈再次执行 linuxdeploy，必须保留 --output appimage

#### 普通应用

继续使用用户已经验证的原命令：

```bash
# 为普通应用完成 linuxdeploy 输出阶段和 AppRun 处理
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage
```

#### GTK 应用

已经确认是 GTK 3 时，明确指定 GTK 主版本：

```bash
# 明确要求 GTK 插件部署 GTK 3
export DEPLOY_GTK_VERSION=3

# 部署 GTK 运行资源、生成 GTK hook，并完成 AppRun 包装
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage
```

GTK 插件也支持 GTK 2 和 GTK 4。只有主程序真实使用对应主版本时，才把 `DEPLOY_GTK_VERSION` 改为 `2` 或 `4`；不得跨主版本混用。主版本能够可靠自动识别时可以不设置，但已确认版本时优先显式设置。

#### Qt 应用

先确认主程序实际使用 Qt 5 还是 Qt 6。linuxdeploy-plugin-qt 读取的变量名是大写 `QMAKE`，变量值必须是对应的 qmake 可执行文件名或完整路径，不是单独写数字 `5` / `6`。

Qt 6 应用使用：

```bash
# 指定 Qt 6 的 qmake，确保插件从 Qt 6 路径部署资源
export QMAKE=qmake6

# 部署 Qt 6 plugins、资源和 hook，并完成 AppRun 包装
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

Qt 5 应用使用：

```bash
# 指定 Qt 5 的 qmake，确保插件从 Qt 5 路径部署资源
export QMAKE=qmake

# 部署 Qt 5 plugins、资源和 hook，并完成 AppRun 包装
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

如果构建环境中的命令名不同，应把 `QMAKE` 设置为 `command -v qmake6` / `command -v qmake` 得到的真实完整路径；不得猜测路径。插件已经能够明确找到唯一且正确的 qmake 时可以不设置 `QMAKE`，但同时安装 Qt 5 和 Qt 6 或自动识别可能选错时必须显式设置。

Qt 5 / Qt 6 的运行库、`QMAKE`、qmake / qtpaths、platform plugins、输入上下文和 QML 路径必须保持同一主版本。

#### 需要额外动态加载库的 GTK 应用

linuxdeploy 只能从可见 ELF 依赖自动收集库。NSS、provider、`dlopen` 模块或其他动态加载库确实无法自动发现时，按证据使用 `-l` 精确补入。用户已经验证的命令原样保留：

```bash
# 为 GTK 应用精确补入无法自动发现的 NSS 运行库
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage -l /usr/lib/x86_64-linux-gnu/libnss3.so -l /usr/lib/x86_64-linux-gnu/libnssutil3.so  -l /usr/lib/x86_64-linux-gnu/libsmime3.so -l /usr/lib/x86_64-linux-gnu/libsoftokn3.so
```

只有当前应用确实需要这些库时才使用；不得把这组 NSS 库复制到所有 GTK 项目。其他缺失库也必须逐个核实后追加独立 `-l`，禁止使用宽泛目录或通配符碰运气。

### 第四步：核对 linuxdeploy 自动生成的 AppRun 执行链

第二次 linuxdeploy 的 `--output appimage` 会完成输出阶段。存在 Qt、GTK、GStreamer 等 hook 时，标准结果是：

```text
AppRun
├── source apprun-hooks/<当前插件 hook>
└── exec AppRun.wrapped
```

实际目录中应看到：

- 顶层 `AppRun`：linuxdeploy 自动生成，负责加载 hook；
- `AppRun.wrapped`：保存第二步写入的自定义启动逻辑；
- `apprun-hooks/linuxdeploy-plugin-qt-hook.sh`、`linuxdeploy-plugin-gtk.sh` 或当前项目实际启用的 hook；
- linuxdeploy 自动整理的 `usr/bin`、`usr/lib`、`usr/share`、desktop、icon 和根目录链接。

禁止手工创建或改写 `AppRun.wrapped`。linuxdeploy 完成后也不得无依据覆盖顶层 `AppRun`，否则会绕过自动生成的 hook。

没有使用输入插件的普通应用不一定产生 `apprun-hooks` 或 `AppRun.wrapped`；必须以当前项目最终 AppDir 的真实结构为准，不得为了“结构一致”伪造 hook。

### 第五步：忽略 linuxdeploy 中间 AppImage，用 appimagetool 最终封装

linuxdeploy 在第一步和第三步生成的 AppImage 只用于完成 linuxdeploy 输出阶段，不能作为正式发布资产。最终必须对同一个 AppDir 使用官方 appimagetool 和从 `AppImage/type2-runtime` 官方动态入口取得的 `runtime-x86_64` 重新封装。

用户本地已经验证的原命令如下，必须原样保留：

```bash
# 使用本地 Type 2 runtime 对同一个 AppDir 最终封装
export ARCH=x86_64; appimagetool -n ./AppDir --runtime-file ~/Appimages/BuildAppimageTools/runtime-x86_64
```

GitHub Actions 中应使用仓库构建目录里的 runtime，并明确指定稳定输出资产名，例如：

```bash
# 在 GitHub Actions 中使用官方 Type 2 runtime 生成明确命名的正式资产
export ARCH=x86_64; appimagetool -n ./AppDir ./dist/<应用名>.AppImage --runtime-file ./source/runtime-x86_64
```

只发布 appimagetool 最终生成的文件。linuxdeploy 中间 AppImage必须留在临时位置或排除在发布目录之外，防止上传错误产物。

## AppRun 变量按项目实际需要添加

### 通用基础

通常只需要当前应用真实使用的 `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS`、`GSETTINGS_SCHEMA_DIR`、工作目录和主程序入口。路径必须对应最终 AppDir，不能为了模板完整把 `usr`、`bin`、`lib`、`plugins`、`share`、`translations` 全部重复塞入每个变量。

### Qt

只有 Qt 应用才加入 `QT_PLUGIN_PATH`、`QT_QPA_PLATFORM_PLUGIN_PATH`、`QML_IMPORT_PATH`、`QML2_IMPORT_PATH`、`QT_QPA_PLATFORM` 或 `QT_QPA_PLATFORMTHEME`。

`QT_AUTO_SCREEN_SCALE_FACTOR`、`QT_SCALE_FACTOR`、`QT_STYLE_OVERRIDE`、`QT_QPA_PLATFORMTHEME`、`QT_QPA_PLATFORM` 和 `QT_FONT_DPI` 会影响缩放、主题、平台后端与字体 DPI，不是 linuxdeploy 通用模板；只在上游要求、现有稳定基线、日志或真实运行反馈证明需要时加入。

### GTK

GTK plugin 自动生成的 hook 会设置 GTK 数据、schemas、typelib、immodules、pixbuf loader 和主题相关变量。自定义 AppRun 中不要无依据重复覆盖 `GTK_PATH`、`GTK_THEME`、`GTK_IM_MODULE_FILE`、`GDK_PIXBUF_MODULE_FILE` 或 `GDK_BACKEND`。

`NO_AT_BRIDGE` 会影响辅助功能，也不是所有 GTK / Qt 应用都必须设置。

### GStreamer

只有应用确实需要动态加载 GStreamer modules 时才启用 `--plugin gstreamer`。不要因为某个相近项目使用 GStreamer，就把插件和搜索路径加入所有 GUI 应用。

## 检查要求

可以在本地、容器或临时目录执行与当前修改直接相关的检查，但不得把 test / smoke 代码写进正式脚本。

至少核对：

- 第一次普通 linuxdeploy 已创建 / 整理 AppDir；
- 第二步写入的 AppRun 路径、引号、工作目录和 `"$@"` 传参正确；
- 第二次 linuxdeploy 保留 `--output appimage`，并只启用当前技术栈需要的插件；
- GTK 项目的 `DEPLOY_GTK_VERSION` 与主程序一致；
- Qt 5 / Qt 6 没有混用；
- 额外 `-l` 只包含当前应用确实需要且无法自动发现的库；
- 最终 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks` 执行链正确；
- linuxdeploy 生成的中间 AppImage没有进入发布目录；
- 正式资产由 appimagetool + 官方 Type 2 runtime 生成；
- workflow 没有新增临时 test workflow、测试 Job 或测试 Step；
- 完整 diff 没有临时日志、解包目录、缓存或无关改动。

## 不计入的已核对项目

- `htop/build_htop.sh`：明确使用 quick-sharun，不使用 linuxdeploy。
- `goldendict-ng/build_goldendict-ng.sh`：只有注释提到 linuxdeploy，构建脚本没有实际调用 linuxdeploy。
