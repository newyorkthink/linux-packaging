# 生成应用构建脚本

## 用途与影响

入口：[generate_build_script.py](./generate_build_script.py)。

使用 [固定模板清单](../../templates/README.md) 中的一份完整模板生成 `build_*.sh`。只替换当前模板的占位参数，其他内容原样输出。默认输出统一 diff。显式传入 `--write` 会创建或覆盖指定脚本。现有文件权限继续保留，新文件具有执行权限。

没有适用模板时，先说明具体冲突，授权前保留已有构建脚本。专用流程按 [AGENTS.md](../../AGENTS.md) 逐次取得用户授权。禁止提出、新增或登记清单外模板。

## 统一远端生成入口

使用生成器时，统一使用 [同一个生成工作流](../../.github/workflows/generate-build-script.yml)，不创建应用专用工作流或内置默认应用。通过 GitHub 连接器更新 [统一请求文件](../../.github/build-script-request.json) 后，在 `main` 上触发生成；也可以在 GitHub Actions 页面手动输入同样的完整请求 JSON。

公共请求文件默认只有空任务结构：`{"template":"","output":"","params":{}}`，不预填任何应用、日期或示例任务。请求只包含三个字段：`template` 为固定清单内的模板相对路径，`output` 为正式脚本路径，`params` 为该模板的参数对象。只为当前已获授权的生成任务填写实际值；已有应用目录必须存在，`build_*_old.sh` 不得作为生成目标。

空任务会跳过生成和产物上传。完整请求在 GitHub runner 运行仓库生成器，只输出脚本，不自动覆盖仓库文件。日志统一使用 `BUILD_SCRIPT_GENERATOR_METADATA=` 和 `BUILD_SCRIPT_GENERATOR_BASE64=`，同时提供生成脚本及元数据产物；元数据包含模板、目标路径、源码提交、GitHub 原生 run ID、运行次数和输出的 SHA-256，不自造任务标识。

通过连接器取回生成器原始输出，核对后按用户要求原样覆盖正式脚本。任务完成或停止后，将请求还原为空任务结构；需要覆盖脚本时，与覆盖同次提交清空请求，不把本次应用参数留成公共默认。

按标准重写时，先将旧版原样保存为同目录的 `build_*_old.sh` 并排除所有 Action，再全新生成正式脚本。出现实际报错或用户反馈后才恢复对应必要内容并注明专属；用户最终确认全部正常后删除旧版备份，不继续保留。

禁止在用户本机下载、保存参数、运行生成器或执行任何检查。以下命令仅用于说明 GitHub runner 内的生成器接口。

## 运行条件

需要 Python 3.8 或更高版本和 Bash。输出必须是仓库内已存在的一级应用目录下的 `build_*.sh`，路径不得经过软链接。生成器先校验参数和 Bash 语法。应用来源、参数取值与实际构建仍须按对应打包规范核实。

## 使用方法

以下命令仅在 GitHub runner 的仓库根目录执行，不得在用户本机执行。先按选定模板准备 JSON 参数文件。JSON 键使用去掉两侧双下划线的占位名称。以下是 Arch 原生模板的参数结构，尖括号内容须替换。

```json
{
  "SYSTEM_PACKAGE": "<主软件包名>",
  "DEPENDENCY_ARGS": [],
  "ICON": "/usr/share/icons/<图标相对路径>",
  "DESKTOP": "/usr/share/applications/<桌面入口文件名>",
  "APP_BASENAME": "<产物名主体>",
  "SCAN_ARGS": ["/usr/bin/<程序名>"]
}
```

```bash
# 预览生成内容与目标脚本的差异。
python3 scripts/build/generate_build_script.py --template "<模板相对路径>" --params "<参数文件>" --output "<应用目录>/build_<名称>.sh"

# 输出完整生成稿，供核对或展示。
python3 scripts/build/generate_build_script.py --template "<模板相对路径>" --params "<参数文件>" --output "<应用目录>/build_<名称>.sh" --stdout
```

下面的命令会创建或覆盖指定的构建脚本。核对预览并确认写入范围后执行。

```bash
# 将核对通过的生成结果写入指定构建脚本。
python3 scripts/build/generate_build_script.py --template "<模板相对路径>" --params "<参数文件>" --output "<应用目录>/build_<名称>.sh" --write
```

## 参数说明

| 参数 | 内容 |
| --- | --- |
| `--template` | 相对 `templates/` 的登记路径。 |
| `--params` | UTF-8 JSON 对象文件，或用 `-` 从标准输入读取。缺少必填键、出现未登记键或重复键时会报错。 |
| `--output` | 相对仓库根目录的目标脚本路径。 |
| `--stdout` | 输出完整生成稿。 |
| `--write` | 写入目标脚本。与 `--stdout` 互斥。 |

普通占位参数使用字符串，`VERSION_FIELD` 使用正整数。包名列表使用 JSON 数组，模板允许为空的依赖列表用 `[]`。

`linuxdeploy-gtk-deb.sh` 支持两种互斥来源：原 GitHub 模式继续提供 `GITHUB_REPOSITORY` 与 `RELEASE_ASSET_PATTERN`；官网直链模式改为提供 `DEB_URL`、`DEB_PACKAGE`、`DEB_ARCH`，并按实际来源可选提供 `DEB_SHA256`。两种模式都提供 `DEB_FILENAME` 和原有路径、依赖参数。官网 URL 必须为 HTTPS，包名及架构用于安装前校验，版本读取本次 DEB 的完整元数据。

`DEB_SHA256` 为官方提供的 64 位十六进制 SHA-256；官网没有摘要时省略该字段。公共入口会记录实际下载文件的 SHA-256。生成器只根据来源参数选择已登记的固定下载调用，AppRun、GTK 部署和封装阶段保持同一模板，不接受自定义代码块。

`linuxdeploy-cli-apt.sh` 默认保持原有 Ubuntu APT 模式：提供 `APP_NAME`、`APT_PACKAGES`、`APT_MAIN_PACKAGE`、`APT_EXTRA_PACKAGES` 和 `MAIN_EXECUTABLE`。从已归档的官方 DEB 打包时，改为提供 `RELEASE_TAG`、`GITHUB_REPOSITORY`、`DEB_FILENAME`，不再填写 `APT_MAIN_PACKAGE` 和 `APT_EXTRA_PACKAGES`；软件版本取自本次校验通过的 DEB 元数据。此模式只使用现有的无框架插件模板，不自动启用 Qt、GTK 或 GStreamer 插件。

归档 DEB 需要调整桌面入口时，可同时提供 `DESKTOP_FILE`（AppDir 内的 `usr/share/applications/*.desktop` 路径）、`ICON_FILE`（安装后的 `/usr/share/icons/*.png` 路径）、`DESKTOP_EXEC` 和 `DESKTOP_ICON`。生成器只修改从 DEB 提取的 desktop 副本，要求四项同时提供；未提供时原样保留上游桌面资源。

全部 quick-sharun 模板统一使用 `SCAN_ARGS`，必须显式提供非空数组，包含当前应用需要的完整初始扫描列表。需要程序目录时必须将该目录一并填写，不能只迁移旧的额外目标，也不能省略或提供空数组。生成器不默认追加 `AppDir/bin/*`、系统程序或库，不扫描系统来补齐参数。

扫描参数中的字符串按字面路径处理。确需展开通配符时使用 `{"glob": "<实际程序目录>/*"}` 形式，并将占位内容替换为实际的绝对路径或 `AppDir/` 路径。生成脚本中保留该通配符，由构建时的 Shell 展开。

占位参数的完整定义见 [linuxdeploy 规范](../../linuxdeploy_projects.md#唯一标准模板) 和 [quick-sharun 规范](../../anylinux_projects.md#唯一标准模板)。

### 可选协议登记

使用 quick-sharun 模板且应用确实需要浏览器回跳时，可在生成请求的 `params` 中加入 `PROTOCOL_HANDLER`。以下是该可选项的结构，尖括号内容按实际应用替换。

```json
{
  "PROTOCOL_HANDLER": {
    "desktop_file": "<桌面入口文件名>.desktop",
    "name": "<应用显示名>",
    "comment": "<桌面入口说明>",
    "icon": "<图标名>",
    "wm_class": "<窗口类>",
    "categories": "<分类>;",
    "schemes": ["<协议名>"],
    "mime_extra": []
  }
}
```

`schemes` 填已核实的应用自定义协议名，使用小写且省略 `://`。支持一个或多个互不重复的协议。`mime_extra` 可省略，仅声明附加 MIME 类型。桌面字段使用单行文本，`desktop_file` 与 `icon` 分别填写单独的文件名与图标名，`categories` 沿用 desktop 的分号格式。公共 hook 无法原样写入的字段值会在生成时被拒绝。

生成器在最终封装前输出一次 [公共协议登记调用](../../common/desktop/write_scheme_hook.sh)，按 `APP_BASENAME` 生成 `AppDir/bin/20-<产物名主体>-protocol.hook`。省略 `PROTOCOL_HANDLER` 时，该步骤及其注释和空行一起省略。未声明该占位项的模板会拒绝该参数。

以后增加其他可选步骤时，由适用模板在对应构建阶段声明独占一行的占位项，由生成器登记其参数校验和固定输出。生成请求沿用现有 `params` 结构，只提供已登记的配置数据。

## 执行结果

预览输出与目标脚本的差异，已有内容完全相同时输出为空。实际写入成功后输出目标路径。模板、参数、路径或语法检查失败时返回非零退出码。生成器本身只检查语法和生成结果。
