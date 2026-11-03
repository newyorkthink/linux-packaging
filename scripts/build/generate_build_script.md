# 生成应用构建脚本

## 用途与影响

入口：[generate_build_script.py](./generate_build_script.py)。

根据 [模板总索引](../../templates/README.md) 中登记的一份完整模板生成 `build_*.sh`。只替换当前模板的占位参数，其他内容原样输出。默认输出统一 diff。显式传入 `--write` 会创建或覆盖指定脚本。现有文件权限继续保留，新文件具有执行权限。

## 运行条件

需要 Python 3.8 或更高版本和 Bash。输出必须是仓库内已存在的一级应用目录下的 `build_*.sh`，路径不得经过软链接。生成器先校验参数和 Bash 语法。应用来源、参数取值与实际构建仍须按对应打包规范核实。

## 使用方法

在仓库根目录的 Linux 终端执行。先按选定模板准备 JSON 参数文件。JSON 键使用去掉两侧双下划线的占位名称。以下是 Arch 原生模板的参数结构，尖括号内容须替换。

```json
{
  "SYSTEM_PACKAGE": "<主软件包名>",
  "DEPENDENCY_ARGS": [],
  "ICON": "/usr/share/icons/<图标相对路径>",
  "DESKTOP": "/usr/share/applications/<桌面入口文件名>",
  "APP_BASENAME": "<产物名主体>",
  "SYSTEM_SCAN_ARGS": ["/usr/bin/<程序名>"]
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

普通占位参数使用字符串，`VERSION_FIELD` 使用正整数。包名列表和扫描参数使用 JSON 数组，允许为空的参数用 `[]`。扫描参数的字符串按字面路径处理，确需展开通配符时使用 `{"glob": "/usr/lib/<库名>*.so"}` 形式，将示例中的占位内容换成实际名称。占位参数的完整定义见 [linuxdeploy 规范](../../linuxdeploy_projects.md#唯一标准模板) 和 [quick-sharun 规范](../../anylinux_projects.md#唯一标准模板)。

## 执行结果

预览输出与目标脚本的差异，已有内容完全相同时输出为空。实际写入成功后输出目标路径。模板、参数、路径或语法检查失败时返回非零退出码。生成器本身只检查语法和生成结果。
