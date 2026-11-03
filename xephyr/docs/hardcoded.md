# Xephyr 固定配置依据

| 配置 | 固定值及作用 | 依据与记录 |
| --- | --- | --- |
| Arch 包和可执行入口 | 安装 `xorg-server-xephyr xorg-xkbcomp xkeyboard-config adwaita-icon-theme`。收集 `/usr/bin/Xephyr` 和 `/usr/bin/xkbcomp`。 | [Arch Xephyr 文件表](https://archlinux.org/packages/extra/x86_64/xorg-server-xephyr/files/)与[原脚本](https://github.com/newyorkthink/linux-packaging/blob/84c4f4fcd3f98e7ab106488a01495236c80a58db/xephyr/build_xephyr.sh)。 |
| 桌面入口和图标 | 临时 `Xephyr.desktop` 使用 `Exec=Xephyr`、`Icon=video-display-symbolic`、`Categories=System;Utility;`、`Terminal=false`，图标来自 `/usr/share/icons/Adwaita/symbolic/devices/video-display-symbolic.svg`。 | 沿用原脚本，为缺少桌面资源的 Xephyr 提供封装元数据。 |
| 跟踪开关 | `STRACE_MODE=0`，构建时跳过启动跟踪。 | 原脚本记录 CI 缺少外层 X 显示。 |
| XKB 映射 | 将 `/usr/bin/xkbcomp` 和 `/usr/share/X11/xkb` 分别映射到 `${SHARUN_DIR}/bin/xkbcomp` 和 `${SHARUN_DIR}/share/X11/xkb`。规则复制到 `AppDir/share/X11/xkb/`。 | 继承 X server 的编译时路径及原脚本映射，详见 [README 修正记录](../README.md#修正记录)。 |
| 许可证 | 将 `xorg-server-xephyr`、`xorg-xkbcomp`、`xkeyboard-config` 的系统许可证目录复制到 `AppDir/share/licenses/`。 | 沿用原有随包分发范围。 |
| 版本及产物 | 从已安装的 `xorg-server-xephyr` 动态读取版本。产物为 `dist/Xephyr.AppImage`，版本记录为 `dist/version.txt`。 | 与[应用清单](../../.github/appimage-apps.json)和公共版本接口一致。 |

这些固定值均来自既有配置。本次可追溯的历史依据为原脚本和 README 修正记录，现有材料未包含原始故障日志全文。构建和实机验证状态见 [README](../README.md#验证状态)。
