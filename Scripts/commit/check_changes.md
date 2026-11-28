# 只读核对改动范围与 Git 文件模式

## 用途与影响

入口：[check_changes.js](./check_changes.js)。比较两个 Git 快照，列出发生新增、修改或删除的路径，并核对目标快照全树中具有固定要求的 Git 文件模式。传入范围清单后，还会报告清单外的改动和清单内无改动的路径。

检查只读取 Git 数据，适用于提交前和提交后核对。完整正文差异、新增文档链接、工作区执行位、语法、构建和运行效果按[验证速查](../README.md#验证速查)另行核对。

## 运行条件

- 终端模式需要 Node.js 18 或更新版本、Git 和仓库工作区。适用于本地或云端已有的工作区。调用权限遵守 [AGENTS.md](../../AGENTS.md) 的环境与授权规则。
- 只有 GitHub 连接器时，使用支持 JavaScript 的编排环境，在内存中运行相同的检查逻辑。连接器提供的是已提交的 Git 快照。

## 使用方法

### Git 工作区

在仓库根目录运行，按实际情况替换提交和路径。

```bash
# 查看帮助
node Scripts/commit/check_changes.js --help

# 比较 HEAD 和当前暂存内容，并核对明确的改动清单
node Scripts/commit/check_changes.js --staged -- "Scripts/README.md"

# 比较两笔已存在的提交
node Scripts/commit/check_changes.js --commits "<基准提交>" "<目标提交>"
```

### GitHub 连接器

1. 从已核对的固定提交读取本脚本完整正文，记为 `source`。通过 `GET /repos/<所有者>/<仓库>/git/trees/<提交号>?recursive=1` 分别获取基准和目标提交的完整递归 Git 树，记为 `base` 和 `head`。
2. 解析连接器返回的树 JSON，保留 `tree` 和 `truncated` 字段。有范围清单时传入 `expectedPaths`，路径与终端模式一致。
3. 在编排环境调用以下入口并读取结果。

```javascript
const { checkChanges, formatCheckResult } = new Function(source + "\nreturn { checkChanges, formatCheckResult };")();
const result = checkChanges({ base, head, expectedPaths: ["Scripts/README.md"] });
text(formatCheckResult(result));
```

## 参数说明

| 参数 | 行为 |
| --- | --- |
| `--staged` | 比较 `HEAD` 和实际暂存内容。未暂存改动、未跟踪文件和仅执行过 `git add -N` 的路径不在比较范围内。 |
| `--commits <基准> <目标>` | 解析为两笔已存在的提交并直接比较两棵树。 |
| `-- <路径> ...` | 可选的完整仓库相对路径清单，精确匹配，不展开通配符。改名按旧路径删除和新路径新增报告，两条路径均应列入清单。 |
| `--help`、`-h` | 输出用法。 |

固定模式与[本地文件权限检查](./check_file_modes.md)对应。符号链接、子模块和没有固定模式要求的普通文件仍会列出改动，模式规则按实际用途核对。

## 执行结果

| 状态 | 终端退出码 | 说明 |
| --- | --- | --- |
| `pass` | `0` | 已执行的检查通过。省略范围清单时，只列出改动并核对固定模式。 |
| `fail` | `1` | 存在 Git 模式错误，或实际改动与范围清单不一致，结果列出相关路径。 |
| `incomplete` | `2` | Git 数据或参数有误，或存在未合并索引、截断的远端 Git 树等证据缺口。 |

返回 [提交维护索引](./README.md) 或 [维护脚本总索引](../README.md)。
