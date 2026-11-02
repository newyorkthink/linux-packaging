# DingTalk 固定配置依据

以下配置对应当前直接 appimagetool 构建。软件版本、DEB 地址与摘要均由公共 AUR 入口动态取得；这里的源码快照仅用于说明来源，不作为构建时的固定下载版本。

| 配置 | 来源和用途 |
| --- | --- |
| AUR `dingtalk-bin`、架构 `x86_64`；DEB 包名 `com.alibabainc.dingtalk`、架构 `amd64` | 当前 AUR `.SRCINFO` 和实际官方 DEB control。分别传入两个生态的架构名称，不猜测映射；安装前核对包身份。 |
| Ubuntu 24.04 | 沿用此前 CI；libasound2t64、libcups2t64、libgtk2.0-0t64 等名称与该环境对应，不据此换 runner。 |
| `opt/apps/com.alibabainc.dingtalk/files/*-Release.*` | 已校验的官方 DEB 中的实际产品目录；要求唯一匹配，避免上游布局变化时搬错资源。 |
| `opt/dingtalk/release`、`plugins/dtwebview/libcef.so` | AUR 归一化布局及官方包中实际 CEF 位置。保留程序与资源相对目录，AppRun 工作目录也固定到 release。 |
| `usr/lib/dingtalk-runtime` | 沿用既有外部依赖收集目录；主程序目录、CEF 目录、该目录按原顺序组成 LD_LIBRARY_PATH，不追加宿主库路径改变优先级。 |
| `LD_PRELOAD=$CEF_LIB_DIR/libcef.so` | 旧实测 AppRun 及官方 Elevator.sh 的 CEF 预加载行为；保留宿主既有 LD_PRELOAD 的追加方式，不复用官方脚本中的系统绝对路径。 |
| `wayland;xcb`、缩放默认 `1` | 沿用 AUR 启动脚本和原实测 AppRun；宿主已设置时继续优先使用宿主值。 |
| `QT_IM_MODULE=fcitx`、`GTK_IM_MODULE=fcitx`、`XMODIFIERS=@im=fcitx` 的默认值 | 原 AppRun 的输入兼容设置；宿主覆盖行为不变。插件路径继续指向官方 bundle 的 plugins / platforms，不替换 Qt 主版本。 |
| 完整 NSS/NSPR 16 文件与 `NSSUTIL` / `NSPR` 前缀 | 原 CI 的运行库清单和符号检查；公共复制入口按需补 NSPR，缺文件或符号不匹配时阻止继续构建。 |
| ELF 可执行栈清理 | 原 AUR 与仓库基线已处理钉钉私有库的可执行栈；保留对所有 EXEC / DYN ELF 的清理范围，不只列举旧版本的两个文件名。 |
| doctor、libgtkglext、libgdkglext 排除 | 原 CI 记录的 libpangox 缺失；只从 AppDir 移除主程序不用的旧诊断组件。 |
| desktop `Exec=dingtalk`、`Icon=com.alibabainc.dingtalk` | 保留旧净化结果与 AppRun 软链接入口；避免 AUR 重复 Name 键使 desktop 校验失败。 |
| `librsvg2-bin` | 给公共封装入口提供 rsvg-convert，处理新版 appimagetool 拒收 SVG .DirIcon 的真实故障；应用补丁保留原 SVG。 |
| `dingtalk.AppImage`、`dist/version.txt` | 保留现有 Release 资产名与软件清单 key，版本保存统一由公共封装入口完成。 |

源码依据为 [AUR 当前所读 PKGBUILD](https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=dingtalk-bin&id=9f15353cb6556398d3cd3ac594a57ca4a824200a)、同次 `.SRCINFO`、desktop 与 dingtalk.sh，以及本仓库迁移前的 [build](https://github.com/newyorkthink/linux-packaging/blob/246fcf3c0304a5e4b33a44e9c74da8d7476af0e3/dingtalk/build_dingtalk.sh) 和 [CI 入口](https://github.com/newyorkthink/linux-packaging/blob/246fcf3c0304a5e4b33a44e9c74da8d7476af0e3/.github/scripts/ci_build_dingtalk.sh)。采用范围和未扩大的配置边界见 [模板差异](./template-deviations.md)。
