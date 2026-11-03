# Newsboat 固定配置依据

| 配置 | 取值和用途 | 依据 |
| --- | --- | --- |
| 应用与入口 | `newsboat` 包提供 `/usr/bin/newsboat` 和 `/usr/bin/podboat`，在同一次依赖收集中传入。 | [Arch 官方包文件表](https://archlinux.org/packages/extra/x86_64/newsboat/files/)及原构建脚本。 |
| 应用安装参数 | `newsboat json-c libxml2 sqlite stfl buku kitty ruby asciidoctor rust swig`。其余原有包由公共基础环境安装。 | 原构建脚本及公共 `--base` 的包清单。 |
| 图标 | `/usr/share/icons/hicolor/scalable/apps/newsboat.svg`。 | Arch 官方包文件表。 |
| 桌面入口 | 仓库维护的 [newsboat.desktop](../newsboat.desktop) 保留 `Exec=newsboat` 和 `Terminal=true`。构建时保留 `STARTUPWMCLASS=newsboat`。 | 原构建脚本及 desktop。 |
| 产物及版本 | `newsboat/dist/newsboat.AppImage` 和 `newsboat/dist/version.txt`。版本由本次实际安装的 Arch 包提供。 | 原生入口模板、[应用清单](../../.github/appimage-apps.json)和公共版本接口。 |

现有记录给出了上述参数的来源和用途，未提供对应的原始故障日志。模板差异见 [template-deviations.md](./template-deviations.md)。
