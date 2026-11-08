# Poppler Utilities 专属差异

本应用采用 Ubuntu 24.04 官方 `poppler-utils` 与 `poppler-data`，整体按 LinuxDeploy CLI 标准分区组织。公共处理与 [LinuxDeploy CLI 模板](../../templates/appimage/linuxdeploy-cli-apt.sh) 一致；仅保留一个 AppImage 对应 13 个命令所必需的桌面资源与 AppRun 分派逻辑。

| 位置 | 处理及原因 | 代码或依据 |
| --- | --- | --- |
| 应用来源 | 使用公共 APT 入口下载与已安装版本一致的 `poppler-utils`、`poppler-data`，按官方 DEB 路径解包，保留 13 个命令和 CMap、编码数据。 | [对应代码](../build_poppler-utils.sh#L34) |
| 官方 PNG 图标 | CLI 工具没有通用桌面图标，保留原 Poppler 官方 PNG 来源；由公共下载入口取得。 | [对应代码](../build_poppler-utils.sh#L42) |
| desktop | 保留 `Terminal=true`、`Exec=pdftotext %F` 和 `Icon=poppler-utils` 的套件入口，供 LinuxDeploy 和最终封装使用。 | [对应代码](../build_poppler-utils.sh#L45) |
| AppRun | 保留旧版已验证的 13 命令 `ARGV0` 软链接分派，也支持首参数传入命令名；无命令名时默认执行 `pdftotext`。该逻辑超出单入口 CLI 标准模板的启动行为。 | [对应代码](../build_poppler-utils.sh#L58) |
| 运行库与数据目录 | 原 AppRun 的 `PATH`、`LD_LIBRARY_PATH`（含多架构库目录）及 `XDG_DATA_DIRS` 原样保留，保证包内命令和数据目录查找行为不变。 | [对应代码](../build_poppler-utils.sh#L65) |
| 构建与封装 | 保留 Ubuntu 24.04 + LinuxDeploy + 官方 appimagetool/Type 2 runtime；公共工具入口负责配置环境，最终封装入口负责生成、摘要与版本写入。 | [对应代码](../build_poppler-utils.sh#L96) |

## 专属注释原文

- `# 本程序专属处理：准备 Poppler 桌面入口和官方 PNG 图标的包内目录。`
- `# 本程序专属处理：通过公共下载入口获取 Poppler 官方 PNG 图标。`
- `# 本程序专属处理：为包含 13 个命令的 CLI 套件创建终端桌面入口。`
- `# 本程序专属处理：沿用已验证的 13 个 Poppler 命令及 ARGV0 软链接分派入口。`

这些内容只适用于当前套件，不属于其他 CLI 应用的通用步骤；标准固定注释与阶段以 [LinuxDeploy 注释规范](../../docs/linuxdeploy-comments.md) 为准。历史故障和 lf 实机验证见 [README](../README.md#修复记录)。
