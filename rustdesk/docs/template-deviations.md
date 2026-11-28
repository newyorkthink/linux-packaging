# RustDesk 模板差异

RustDesk 采用[直接 appimagetool 封装标准](../../linuxdeploy_projects.md#直接-appimagetool-模式同一体系的精简流程)。完整 AppDir 在本次构建时通过解包官方 AppImage 取得。

| 阶段 | 处理 | 依据与影响 |
| --- | --- | --- |
| 准备构建目录 | 使用公共工作区入口重建 `source`、`AppDir` 和 `dist`。 | `AppDir` 由本次官方 AppImage 解包生成。封装工具位于 `source/tools`。 |
| 下载并准备应用 | 公共下载入口选择 RustDesk 最新正式 Release 中匹配的 x86_64 AppImage，校验 GitHub SHA-256 并返回实际版本。 | 发布版本对应这次下载的官方资产。 |
| 下载并准备应用 | 公共 AppImage 解包入口生成完整上游目录，移入 `AppDir` 后保留官方 ELF `AppRun` 和原有运行目录。 | 先前包装官方 ELF 启动器的方案曾在实机报错，见[故障记录](../README.md#2026-09-23恢复官方-elf-apprun)。 |
| 下载并准备应用 | 将 `AppRun.env` 中的 `XDG_SESSION_TYPE` 设为 `x11`。 | 变更仅作用于包内，保留经[实机确认](../README.md#2026-09-23x11-主机端实机确认)的 X11 主机端行为。 |

固定 X11 设置的依据见[固定配置](./hardcoded.md)。上游 quick-sharun 收集、依赖部署和自更新 Hook 未启用，见[上游打包差异](./pkgforge-differences.md)。
