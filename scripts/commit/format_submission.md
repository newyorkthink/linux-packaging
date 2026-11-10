# 生成提交说明和实机验证记录

## 用途与影响

使用 [format_submission.js](./format_submission.js) 将结构化字段转换为提交说明和实机验证正文。提交说明使用 [AGENTS.md](../../AGENTS.md#提交说明格式) 的格式，实机正文读取 [实机验证通过记录模板](../../docs/templates/documentation/real-machine-validation.md)。

脚本在内存中生成预览。核对事实和完整差异后，按仓库授权规则通过 GitHub 连接器提交到 `main`。

## 运行条件

需要 GitHub 连接器和支持 JavaScript 的云端编排环境。从本次已核对的同一个 `main` 提交 SHA 读取脚本、目标文档和所需模板。执行前通读脚本原文，调用时将模板和用户提供的事实作为数据传入。

## 使用方法

1. 通过 GitHub 连接器读取 `scripts/commit/format_submission.js` 完整正文，记为 `formatterSource`。涉及实机验证时，读取 `docs/templates/documentation/real-machine-validation.md` 完整正文，记为 `templateSource`。
2. 将用户确认、截图或日志支持的事实填入 `realMachineValidation`，生成预览。已有 `## 实机验证` 章节时，在其中追加 `entry`。更新已获准的记录时，仅替换对应条目。新建章节时使用 `section`。
3. 核对实际改动、差异和已执行的检查结果，再填 `commit`。通过 GitHub 连接器提交时原样传入 `commitMessage`。

下列代码在提供 `text` 输出的云端 JavaScript 编排环境执行。先准备已读取的 `formatterSource` 和所需的 `templateSource`，再将尖括号占位内容替换为本次事实。只生成一种内容时，省略另一组顶层字段。

```javascript
// 加载已核对的仓库格式脚本。
const formatSubmission = new Function('"use strict";\n' + formatterSource + "\nreturn formatSubmission;")();

// 用本次已有依据的字段生成预览。
const preview = formatSubmission({
  commit: {
    title: "<中文标题>",
    changes: ["<实际改动及其用途>"],
    verification: "<实际检查及其结果>"
  },
  realMachineValidation: {
    template: templateSource,
    date: "<YYYY-MM-DD>",
    application: "<应用名>",
    results: [{
      item: "<实测项目>",
      result: "<通过结果>"
    }]
  }
});

// 查看预览以便核对提交说明和文档正文。
text(preview);
```

## 参数说明

| 字段 | 填写要求 |
| --- | --- |
| `commit.title` | 简洁的中文标题，概括改动对象和结果。 |
| `commit.changes` | 至少一项实际改动及用途，每项为单行文本。 |
| `commit.verification` | 实际执行的检查及结果，脚本添加 `验证` 标签。 |
| `commit.orderedChanges` | 可选。改动确有先后顺序时填 `true`，默认使用无序列表。 |
| `realMachineValidation.template` | 与脚本同一提交的仓库实机验证模板完整正文。 |
| `realMachineValidation.date` | 实测日期，使用有效的 `YYYY-MM-DD`。 |
| `realMachineValidation.application` | 实际验证的应用名。 |
| `realMachineValidation.version` | 可选。填写有依据的版本，反引号由脚本添加。 |
| `realMachineValidation.results` | 可选。每项填 `item` 和 `result`，仅收录已经确认通过的项目。 |
| `realMachineValidation.observations` | 可选。每项为单行文本，写实际日志提示或运行现象及观察到的后续行为。 |

至少提供一组顶层字段。标题、列表正文和实测事实按单行填写，序号、列表标记和段落换行由脚本处理。选填项缺少依据时直接省略。生成实机验证记录的前提是用户已确认通过。

## 执行结果

`commitMessage` 包含中文标题、分点正文和单独的验证条目。`realMachineValidation.heading` 为模板章节标题，`entry` 为日期条目，`section` 为完整章节。

字段名、必填项、日期、模板结构或格式校验失败时，脚本抛出包含具体原因的错误。先依据实际材料修正输入，再重新生成预览。格式通过后仍须按实际证据核对正文和提交说明。
