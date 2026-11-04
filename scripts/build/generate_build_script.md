# 生成应用构建脚本

## 用途与影响

入口：[generate_build_script.py](./generate_build_script.py)。

使用 [固定模板清单](../../templates/README.md) 中的一份完整模板生成 `build_*.sh`。没有适用模板时，说明具体冲突并保留已有构建脚本，禁止提出、新增或登记其他模板。只替换当前模板的占位参数，其他内容原样输出。默认输出统一 diff。显式传入 `--write` 会创建或覆盖指定脚本。现有文件权限继续保留，新文件具有执行权限。

## 统一远端生成入口

所有应用使用 [同一个生成工作流](../../.github/workflows/generate-build-script.yml)，不创建应用专用工作流或内置默认应用。通过 GitHub 连接器更新 [统一请求文件](../../.github/build-script-request.json) 后，在 `main` 上触发生成；也可以在 GitHub Actions 页面手动输入同样的完整请求 JSON。

请求只包含四个字段：`request_id` 为本次唯一请求标识，`template` 为固定清单内的模板相对路径，`output` 为正式脚本路径，`params` 为该模板的参数对象。每次新请求更换 `request_id`；已有应用目录必须存在，`build_*_old.sh` 不得作为生成目标。

工作流在 GitHub runner 运行仓库生成器，只输出脚本，不自动覆盖仓库文件。日志统一使用 `BUILD_SCRIPT_GENERATOR_METADATA=` 和 `BUILD_SCRIPT_GENERATOR_BASE64=`，同时提供生成脚本及元数据产物；元数据包含请求标识、模板、目标路径、源码提交和输出的 SHA-256。通过连接器取回生成器原始输出，核对后按用户要求原样覆盖正式脚本。

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
| `--params` | UTF-8 JSON 对象文件，或用 `-` 从标准输入读取。缺少、多出或重复的键均会报错。 |
| `--output` | 相对仓库根目录的目标脚本路径。 |
| `--stdout` | 输出完整生成稿。 |
| `--write` | 写入目标脚本。与 `--stdout` 互斥。 |

普通占位参数使用字符串，`VERSION_FIELD` 使用正整数。包名列表使用 JSON 数组，模板允许为空的依赖列表用 `[]`。

全部 quick-sharun 模板统一使用 `SCAN_ARGS`，必须显式提供非空数组，包含当前应用需要的完整初始扫描列表。需要程序目录时必须将该目录一并填写，不能只迁移旧的额外目标，也不能省略或提供空数组。生成器不默认追加 `AppDir/bin/*`、系统程序或库，不扫描系统来补齐参数。

扫描参数中的字符串按字面路径处理。确需展开通配符时使用 `{"glob": "<实际程序目录>/*"}` 形式，并将占位内容替换为实际的绝对路径或 `AppDir/` 路径。生成脚本中保留该通配符，由构建时的 Shell 展开。

占位参数的完整定义见 [linuxdeploy 规范](../../linuxdeploy_projects.md#唯一标准模板) 和 [quick-sharun 规范](../../anylinux_projects.md#唯一标准模板)。

## 执行结果

预览输出与目标脚本的差异，已有内容完全相同时输出为空。实际写入成功后输出目标路径。模板、参数、路径或语法检查失败时返回非零退出码。生成器本身只检查语法和生成结果。
