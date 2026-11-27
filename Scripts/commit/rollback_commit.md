# 撤回 main 最新一笔提交

## 用途与影响

使用 [rollback_commit.js](./rollback_commit.js) 预览并撤回 `main` 最新的一笔单父提交。撤回将远端 `main` 移回目标的父提交，目标提交由此退出 `main` 历史。若涉及现有构建或发布的触发路径，需在预览中说明影响。适用规则见 [AGENTS.md](../../AGENTS.md#git-提交撤销统一执行历史删除)。

## 运行条件

在支持 JavaScript 的云端编排环境中使用已认证的 GitHub 连接器。执行阶段需要连接器支持带 `expected_sha` 的引用更新。通过连接器从已核对的远端提交 SHA 读取完整脚本并通读，预览和执行使用同一份正文。

只处理 `main` 当前最新且恰有一个父提交的提交。目标已有后续提交、目标为合并或根提交、目录树读取不完整时停止。

## 使用方法

### 预览撤回范围

把完整脚本正文读入 `rollbackSource`。填写当前仓库全名和用户指定的目标提交 SHA，生成只读预览。

```javascript
// 加载已经核对的撤回脚本。
const rollbackCommit = new Function('"use strict";\n' + rollbackSource + "\nreturn rollbackCommit;")();

// 读取目标提交、父提交和撤回涉及的完整文件变化。
const preview = await rollbackCommit({
  action: "preview",
  repository: "<所有者>/<仓库名>",
  targetSha: "<目标提交 SHA>"
}, { fetch: tools.mcp__codex_apps__github_fetch });

// 在云端会话内保留获审查的原始预览和脚本。
store("rollbackPlan", { source: rollbackSource, preview });
text(preview);
```

向用户列出仓库与分支、目标提交完整 SHA、父提交完整 SHA、每个受影响的路径及恢复效果，并说明这些路径对现有 Actions 和发布流程的影响。`commitUrl` 提供目标提交原始逐行差异，`files` 按撤回方向显示文件对象 SHA 和 Git 模式。`before` 为当前值，`after` 为恢复点的值，`null` 表示该侧没有此路径。重命名按两个路径显示。

### 经用户明确同意后执行

收到用户对该次预览的后续明确同意后，使用同一份脚本和原始预览调用 `apply`。`confirmed` 记录执行者已经核实该次用户授权。

```javascript
// 加载与预览时相同的撤回脚本。
const plan = load("rollbackPlan");
const rollbackCommit = new Function('"use strict";\n' + plan.source + "\nreturn rollbackCommit;")();

// 按用户已明确同意的原始预览执行撤回并复核远端。
const result = await rollbackCommit({
  action: "apply",
  preview: plan.preview,
  confirmed: true
}, {
  fetch: tools.mcp__codex_apps__github_fetch,
  updateRef: tools.mcp__codex_apps__github_update_ref
});
text(result);
```

## 参数说明

| 字段 | 填写要求 |
| --- | --- |
| `action` | 预览填 `preview`，经该次授权后执行填 `apply`。 |
| `repository` | 预览时填写当前仓库的 `所有者/仓库名`。 |
| `targetSha` | 预览时填写目标提交完整 SHA，或至少 7 位十六进制前缀。以预览返回的完整 SHA 为准。 |
| `preview` | 执行时传入用户确认的原始预览对象。 |
| `confirmed` | 当前预览已获用户明确同意时填 `true`。 |

## 执行结果

脚本在更新前复核 `main` 分支头和预览对应的提交与目录树。连接器按预览的目标 SHA 校验远端分支头。拒绝或响应异常后只读取远端查明结果，远端发生变化时按新状态重新列明范围并取得同意。

`applied` 表示连接器更新成功，分支头、最近历史与恢复点的目录树 SHA 均已核对。`verified_after_update_error` 表示连接器更新响应异常，但远端已在获准的恢复点，交付时须说明 `updateError`。远端复核失败时报告实际状态。

本入口唯一的写入是更新 `refs/heads/main`。现有工作流按自身触发规则处理这次更新。Release、Tag 或附件的任何单独变更均按各自的授权流程处理。
