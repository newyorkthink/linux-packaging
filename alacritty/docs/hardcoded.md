# Alacritty 固定配置

下列路径服务于 Alacritty 当前的 LinuxDeploy 布局与 X11 输入修复，不作为其他软件的通用示例。实际代码见 [build_alacritty.sh](../build_alacritty.sh)。

| 配置 | 当前取值 | 依据与影响 |
| --- | --- | --- |
| 包内主程序 | `AppDir/usr/bin/alacritty` | AppRun 直接执行该真实文件。 |
| X11 输入运行库 | `/usr/lib/x86_64-linux-gnu/libxkbcommon-x11.so.0` | 与 Ubuntu 22.04 构建环境相同，LinuxDeploy 按原有要求显式部署。 |
| XKB 数据 | `AppDir/usr/share/X11/xkb` | 从构建环境 `/usr/share/X11/xkb` 复制，AppRun 指定 `XKB_CONFIG_ROOT`。 |
| Compose 数据 | `AppDir/usr/share/X11/locale` | 从构建环境 `/usr/share/X11/locale` 复制，AppRun 指定 `XLOCALEDIR`。 |
| 运行库搜索目录 | `$HERE/usr/lib` | 不继承外层 AppImage 的动态库路径。 |
| 共享数据目录 | `$HERE/usr/share:/usr/local/share:/usr/share` | 优先使用包内数据，同时保留宿主数据目录。 |
| terminfo | `/usr/share/terminfo` | 使用宿主 terminfo，不额外内置。 |
| 构建 Runner | `ubuntu-22.04` | 对齐历史 LinuxDeploy 基线，避免 `ubuntu-latest` 更新时改变构建系统版本。 |

来源和维护原因见[专属差异](./template-deviations.md)，历史故障见 [README](../README.md)。
