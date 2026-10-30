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

## 独立归档清理

[Clean Archived Versions](../.github/workflows/check-archived-versions.yml) 在 main 的归档目录、活动构建清单、工作流或清理脚本变更时自动运行，也支持手动运行。`Build AppImages` 的新运行被请求时也会触发清理，便于尽早处理此前留下的归档记录。该工作流保持独立，不修改原有构建、完整性监督、自愈或逐项发布代码，不设置每天定时任务。

归档时同步维护 [固定资产映射](./appimage-apps.json)，原样登记原构建配置中的 `dir`、`script`、`release_name`；脚本路径仍写移动前的路径，实际文件位于 `archive/<原脚本路径>`。按版本条目的 `asset` 精确匹配，不从目录名猜测软件键。

只有归档索引、README 和原脚本齐全，原目录及活动构建入口均已移除，并且完整分页读取的 Release 资产中没有对应文件，才自动删除匹配的版本条目。正常应用缺包、仍有活动入口、仍有资产或映射不明确时不删。API 失败、空分页响应、清单缺失或重复、摘要异常、main 已变化时停止相应写入，不把这些情况当作资产不存在。

清理使用 `contents: write` 权限，并与逐项发布 Action 共用 `software_versions.json.lock`。取得锁后重新读取最新清单和资产列表，保留等待期间其他 Job 写入的记录；写入后校验整个文件的摘要和内容。预检查没有变化就不创建写锁，也不上传。上传失败且原清单被替换操作移除时，仅在仍持有锁的前提下尝试恢复原快照，清理仍按失败处理。

只删除符合条件的软件记录，不删除 AppImage、归档源码或整个版本清单。结果写入日志和运行摘要。当前登记七个固定资产名；JRiver 的历史资产名会随主版本变化，未登记，也不会匹配仍在使用的 RunImage 资产。恢复项目时同步移除归档映射并恢复构建入口。

此工作流与构建、监督分别调度，没有建立先后依赖，也不会把已经失败的运行自动改为成功。GitHub 不会为重跑发送 `workflow_run: requested` 事件；需要重试清理时，直接手动运行本工作流。
