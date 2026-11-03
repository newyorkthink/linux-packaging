# 归档

不再使用的项目放在这里。脚本和修复记录保留，只是不再构建、不再发布。

以后确认不用的应用，整目录移入 `archive/`，不要直接删除。同时从 workflow 和发布清单里去掉对应入口，并删除 Release 上已经发出的对应产物。若 `latest` Release 的 `software_versions.json` 里有对应条目，同一次删除；本来没有的不要新增。`archive/` 里的旧文件默认不再改。

当前仍在使用的 RunImage 和 AppImage 不要放进来。

| 目录 | 停用日期 | 原因 | 替代 |
| --- | --- | --- | --- |
| [jriver](./jriver/README.md) | 2026-09-25 | AppImage 启动慢，而且 bug 多 | [runimage/jriver-media-center](../runimage/jriver-media-center/README.md) 的 `mediacenter36` |
| [xnconvert](./xnconvert/README.md) | 2026-10-13 | 官方 1.118.0 改用 Qt 6.8.9，这条打包用得少，不再单独维护 | 官方最新 `XnConvert-*-linux-x64.deb` |
| [baidunetdisk](./baidunetdisk/README.md) | 2026-10-21 | linuxdeploy 产物在 glibc 2.41 及以上因 Koffi 可执行栈标记无法启动 | 暂无。重新启用时用 quick-sharun，不沿用这份 linuxdeploy 脚本 |
| [deepseek-harness](./deepseek-harness/README.md) | 2026-10-29 | 这条命令行打包不再使用 | [deepseek-harness-desktop](../deepseek-harness-desktop/README.md) |
| [virt-manager](./virt-manager/README.md) | 2026-10-29 | 确认不再使用 | 无 |
| [zen](./zen/README.md) | 2026-10-29 | 确认不再使用 | 无 |
| [github-desktop](./github-desktop/README.md) | 2026-10-29 | 确认不再使用 | 无 |
| [goldendict-ng](./goldendict-ng/README.md) | 2026-10-29 | 确认不再使用 | 无 |
| [remotedesktopmanager](./remotedesktopmanager/README.md) | 2026-11-03 | 暂不使用；保留 WebView 桥接库缺失的构建错误和恢复待办 | 无 |

## 归档步骤

已登记且具有固定 AppImage 资产名的项目，统一使用 [archive_apps.sh](../scripts/archive/archive_apps.md)。脚本支持同批传入多个目录，默认仅预览；只有明确传入 `--repo` 和 `--yes` 后，才执行目录迁移、登记与引用更新、提交推送、附件删除和版本清理。参数、依赖、实际执行顺序及失败续跑条件见对应说明，不在本页另写一套命令。

执行前先补齐应用 README 中缺失的成功基线、原始错误和恢复待办。脚本会保留已有记录，但不会自动读取日志或代写故障原因。AI 应读取说明后调用统一入口，不重新拼接临时归档或删除逻辑；本机命令或远程执行工具仍须在明确授权的范围内使用。

以下各项作为归档核对清单；脚本先提交推送，再执行发布清理，最后复查结果。推送成功不等于全部归档完成，失败后按脚本说明核对并续跑，不自动回滚或重复提交。

1. 完整保留应用目录、构建脚本、配套文件和修复历史，整体移到 `archive/<原目录>/`；归档后不继续修补或试构建。
2. 在本页和应用 README 顶部登记停用日期、原因、替代入口及是否计划按需恢复。尚未解决的构建或运行错误必须写入应用 README：原始报错、失败阶段、实际版本、源码提交、日志或产物链接、已确认与未确认的原因，以及重新启用前的待办。归档不表示错误已经解决。
3. 从 `.github/appimage-apps.json`、对应 workflow 的手动选项和独立 Job 中移除该应用；同步移除仅收录活动项目的索引条目，处理因移动产生的链接，保留其他应用和公共流程。
4. 在 `archive/appimage-apps.json` 登记原 `dir`、原 `script` 和已经核实的固定 `release_name`。旧脚本保持原样，恢复到原位置后再按待办修复。
5. 删除 Release 中已经核实的该应用产物。若 `latest/software_versions.json` 含对应记录，同次按现有写锁和独立清理机制仅移除匹配条目；本来没有记录就不新增，不覆盖其他应用的并发更新。独立清理只删版本条目，不替代产物删除。
6. 提交前核对完整 diff、整目录文件及权限保留、JSON / YAML、清单与手动选项一致性，以及所有活动入口均已移除。核实 Release 产物和版本条目已移除；任何未完成的删除或未验证结果必须如实说明，不能把提交成功当作构建成功。

## 删除 Release 附件

Release 附件与 Git 仓库文件是两类对象。移动源码目录、删除仓库路径或提交归档，都不会删除已经发布的附件。

统一归档入口已经复用下述附件删除与版本清理机制，不需要在成功后重复执行。仅单独删除附件时使用本节入口。

AI 应先检查 GitHub 工具是否支持删除 Release 附件。连接器缺少此接口时，优先使用已授权的本机 `gh`，可通过 WebCodex 的原生命令工具执行；不要直接改走云浏览器。先确认本机连接可用，再检查 `gh` 登录状态及对目标仓库的发布写权限。浏览器登录与 `gh` 登录相互独立，不能互相代替。

使用 [删除附件说明](../scripts/release/delete_asset.md)统一执行，不在归档文档中维护第二套删除逻辑。需要 Bash、`gh`、`jq` 和目标仓库的发布写权限。在仓库根目录的 Linux 终端执行，替换仓库及附件名；本仓库持续发布的产物使用 `latest` 标签：

```bash
# 按当次归档清单填写已核实的完整附件名，并确认只删除这个附件。
bash scripts/release/delete_asset.sh --repo "<所有者>/<仓库>" --tag latest --asset "<完整附件名>" --yes
```

脚本动态读取 Release 和附件 ID，完整读取所有分页，只删除唯一精确匹配的附件，并重新完整查询确认。目标已不存在且查询成功时报告“无需删除”；查询失败、匹配不唯一、Release 变化或删除后仍有同名附件时返回失败，不能把这些情况当作删除成功。参数、退出码和并发处理见 [脚本说明](../scripts/release/delete_asset.md)。

只处理已经授权的指定附件，不删除整个 Release。`software_versions.json` 中的对应记录仍按上文归档步骤和现有写锁机制处理，附件删除不能替代版本清单清理。

## 重新启用

先阅读该应用 README 中的原始故障、已确认基线和恢复待办，再核对当前官方来源、包布局与上游打包代码。将完整目录移回原位置，同步恢复应用清单、workflow 手动选项及必要的独立 Job、活动索引，并移除本页停用条目和归档映射。

修复阻断问题后完成必要的构建、发布和实际所需功能验证，再更新应用状态。保留历史失败记录，不直接把归档脚本当作当前可用版本，也不自动恢复已确认无效的方案。

## 独立归档清理

[Clean Archived Versions](../.github/workflows/check-archived-versions.yml) 在 main 的归档目录、活动构建清单、工作流或清理脚本变更时自动运行，也支持手动运行。`Build AppImages` 的新运行被请求时也会触发清理，便于尽早处理此前留下的归档记录。该工作流保持独立，不修改原有构建、完整性监督、自愈或逐项发布代码，不设置每天定时任务。

归档时同步维护 [固定资产映射](./appimage-apps.json)，原样登记原构建配置中的 `dir`、`script`、`release_name`；脚本路径仍写移动前的路径，实际文件位于 `archive/<原脚本路径>`。按版本条目的 `asset` 精确匹配，不从目录名猜测软件键。

只有归档索引、README 和原脚本齐全，原目录及活动构建入口均已移除，并且完整分页读取的 Release 资产中没有对应文件，才自动删除匹配的版本条目。正常应用缺包、仍有活动入口、仍有资产或映射不明确时不删。API 失败、空分页响应、清单缺失或重复、摘要异常、main 已变化时停止相应写入，不把这些情况当作资产不存在。

清理使用 `contents: write` 权限，并与逐项发布 Action 共用 `software_versions.json.lock`。取得锁后重新读取最新清单和资产列表，保留等待期间其他 Job 写入的记录；写入后校验整个文件的摘要和内容。预检查没有变化就不创建写锁，也不上传。上传失败且原清单被替换操作移除时，仅在仍持有锁的前提下尝试恢复原快照，清理仍按失败处理。

只删除符合条件的软件记录，不删除 AppImage、归档源码或整个版本清单。结果写入日志和运行摘要。当前登记八个固定资产名；JRiver 的历史资产名会随主版本变化，未登记，也不会匹配仍在使用的 RunImage 资产。恢复项目时同步移除归档映射并恢复构建入口。

此工作流与构建、监督分别调度，没有建立先后依赖，也不会把已经失败的运行自动改为成功。GitHub 不会为重跑发送 `workflow_run: requested` 事件；需要重试清理时，直接手动运行本工作流。
