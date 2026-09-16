# Rainlendar2

本项目在仓库、构建和发布环节统一使用与上游 Linux 程序一致的 `rainlendar2` 名称。

- 项目目录：`rainlendar2/`
- 构建脚本：`rainlendar2/build_rainlendar2.sh`
- Release 产物：`rainlendar2.AppImage`
- 标准终端命令：`rainlendar2`

`rainlendar` 不作为本项目的目录名、构建脚本名、AppImage 文件名或标准终端命令。

## 版本元数据接入（2026-09-16）

- 构建脚本复用 Rainlendar 官方最新正式 Release 的 tag，并仅为统一清单去掉可选的前导 `v`，写入 `dist/version.txt`。
- workflow 使用 `SOFTWARE_KEY=rainlendar2` 接入统一 `software_versions.json`。
- 本次不改变现有 Rainlendar2 打包、GTK/IBus、铃声、Google Tasks 或 Ubuntu 兼容逻辑。
