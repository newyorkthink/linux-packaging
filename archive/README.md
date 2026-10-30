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

## 独立归档检查

[Check Archived Versions](../.github/workflows/check-archived-versions.yml) 在 main 的归档目录、活动构建清单或工作流变更时自动检查，也可以在 Actions 中手动运行。它只有 `contents: read` 权限，只在日志和运行摘要中列出待人工清理的条目，不修改 Release，不接入原有构建、完整性监督或自愈流程。

归档时同步维护 [固定资产映射](./appimage-apps.json)，原样登记原构建配置中的 `dir`、`script`、`release_name`；脚本路径仍写移动前的路径，实际文件位于 `archive/<原脚本路径>`。检查按版本条目的 `asset` 精确匹配，不从目录名猜测软件键。

只有归档索引、README 和原脚本齐全，原目录及活动构建入口均已移除，并且完整分页读取的 Release 资产中没有对应文件，才列为待人工清理。API 读取、清单格式或摘要校验失败时，检查报错，不把失败当作资产不存在。报告注明所检查的 main 快照，实际删除记录仍按上面的归档步骤处理。

当前登记七个具有固定资产名的历史归档项目。JRiver 的历史资产名会随主版本变化，未登记，也不会猜测或匹配仍在使用的 RunImage 资产。恢复项目时同步移除归档映射并恢复构建入口。
