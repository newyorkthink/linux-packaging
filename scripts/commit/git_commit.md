# 本地预览、提交与撤回

## 用途与影响

入口：[git_commit.py](./git_commit.py)。面向个人电脑本地仓库工作区，按固定格式完成差异核对、提交预览、本地 Git 提交，以及尚未推送的本地提交撤回。

- `inspect` 与 `preview` 只读，不修改仓库文件、索引或历史，分别返回绑定当前分支、HEAD、差异和暂存状态的 `diff_id` 与 `preview_id`。
- `commit` 核对 `preview_id` 后，将清单内文件在工作区中的全部改动暂存并在当前分支创建一次本地提交，随后自动核对提交后的分支、父提交、文件内容和提交说明。
- `undo-preview` 只读预览最近一次普通本地提交的撤回目标与影响，返回 `undo_id`；`undo` 原子更新当前分支引用至父提交，保留工作区、暂存区、未跟踪文件和分支 reflog，不新增反向提交。两者均会检查本地记录的远端跟踪分支（`refs/remotes`），拒绝已推送至远端的提交；该检查不联网执行 `fetch`，以本地已知远端快照为准。
- 脚本不执行推送，也不修改远端引用。推送仍使用本地 `git push` 或经授权的 [sync_repo.sh](../sync/sync_repo.md)；已推送至远端的提交撤回仍按 [rollback_commit.md](./rollback_commit.md) 和 [AGENTS.md](../../AGENTS.md#git-提交撤销统一执行历史删除) 处理。

## 运行条件

- Linux 环境、Git 及 Python 3.10 或更新版本；脚本只使用 Python 标准库。
- 脚本根据自身所在位置查找所属 Git 仓库，不受终端当前工作目录影响。
- 仓库须位于普通分支上，且没有未完成的合并、变基、cherry-pick 或 revert 操作。
- 本地 AI 仅在个人电脑本地仓库工作区按 [AGENTS.md](../../AGENTS.md) 获准调用本脚本；执行 `commit` 和 `undo` 前须取得本次明确同意。

## 使用方法

以下命令在 Linux 终端的仓库根目录运行；路径、标题、说明及校验值均须按实际任务替换。除 `undo-preview` 外，其余模式从标准输入读取一个 JSON 对象；交互输入时粘贴 JSON 后按 `Ctrl+D` 结束。

```bash
# 查看脚本帮助
python3 scripts/commit/git_commit.py --help

# 只读核对指定文件的完整差异并获取 diff_id（标准输入：{"files":["<仓库相对路径>"]}）
python3 scripts/commit/git_commit.py inspect

# 结合 diff_id 生成文件清单、提交说明预览和 preview_id（标准输入：{"files":["<仓库相对路径>"],"title":"<中文标题>","changes":["<改动及用途>"],"verification":"<实际检查及结果>","diff_id":"<inspect 返回的值>"}）
python3 scripts/commit/git_commit.py preview

# 取得本次明确同意后执行本地提交（标准输入在预览 JSON 基础上追加 "preview_id":"<preview 返回的值>"）
python3 scripts/commit/git_commit.py commit

# 只读预览当前分支最近一次未推送本地提交的撤回目标并获取 undo_id（无需输入 JSON）
python3 scripts/commit/git_commit.py undo-preview

# 取得本次明确同意后撤回该次本地提交（标准输入：{"commit":"<完整提交号>","undo_id":"<undo-preview 返回的值>"}）
python3 scripts/commit/git_commit.py undo
```

说明：

- `scripts/commit/git_commit.py` 的 Git 模式为 `100755`，也可直接执行 `./scripts/commit/git_commit.py <模式>`。
- 提交完成后，按本次授权执行 `git push origin HEAD:main` 或 `./scripts/sync/sync_repo.sh push` 上传到远端。

## 参数说明

| 字段 / 模式 | 说明 |
| --- | --- |
| `inspect`（默认） | 必填 `files`；读取指定文件相对 `HEAD` 的完整差异（同时含暂存与未暂存改动时分别展示），输出 `diff_id`。 |
| `preview` | 必填 `files`、`title`、`changes`，本仓库调用时必填 `verification`，选填 `diff_id`；校验并预览提交说明，输出 `preview_id`。 |
| `commit` | 使用与 `preview` 相同的输入并追加 `preview_id`；加锁复核后完整暂存指定文件并创建一次本地提交。 |
| `undo-preview` | 无须输入 JSON；只读预览最近一次普通提交、父提交及受核对文件列表，输出 `undo_id`。 |
| `undo` | 必填 `commit`（完整提交号）和 `undo_id`；加锁复核后将当前分支头移回父提交。 |
| `files` | 相对仓库根目录的去重文件路径数组。脚本语法虽支持 `"all"`，但在本仓库中须明确列出获准文件，禁止填写 `"all"`。 |
| `title` | 简洁的单行中文标题，不含列表前缀或占位符。 |
| `changes` | 至少一项改动说明的单行字符串数组，列表标记 `- ` 由脚本生成。 |
| `verification` | 实际执行的检查及结果；本仓库提交时必须填写，验证前缀 `- 验证：` 由脚本生成。 |
| `diff_id` / `preview_id` / `undo_id` | 脚本上一步返回的 64 位十六进制 SHA-256 校验值，用于确保差异、分支与说明未被改动。 |

在本仓库调用时，同时遵守 [AGENTS.md](../../AGENTS.md) 规定：

- `files` 仅填写本次获准提交的明确文件数组，禁止传 `"all"`，禁止部分暂存。
- 每笔提交必填 `verification`，且提交标题与正文均禁止写入任何跳过 CI 的标记（如 `[skip ci]`、`[ci skip]`、`[no ci]`、`[skip actions]`、`[actions skip]`、`skip-checks: true`）。
- 同一任务的获准文件合为一次提交；`undo` 仅用于尚未推送的本地提交。

## 执行结果

- 退出码 `0` 表示当前操作成功。`inspect` 输出文件状态、完整差异与 `diff_id`；`preview` 输出范围、提交说明与 `preview_id`；`commit` 输出新提交号与已提交文件列表；`undo-preview` 与 `undo` 输出撤回前后的提交号与核对结果。
- 校验失败、输入含重复或未知字段、工作区在预览后发生变化、撤回目标已包含在本地已知远端跟踪分支中，或同一仓库已有并发提交/撤回进程时返回非零退出码并说明原因。
- `commit` 在暂存后失败时，已暂存文件保留在暂存区供人工或后续核对；若提交已创建但提交后核对不一致，脚本输出提交号并报错，不擅自改写历史。
- `undo` 仅修改本地分支引用并写入 reflog，不改写工作区文件、暂存区或 `ORIG_HEAD`。

返回 [提交维护索引](./README.md) 或 [维护脚本总索引](../README.md)。
