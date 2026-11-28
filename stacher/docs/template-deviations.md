# Stacher 模板差异

Stacher 采用 Arch Linux x86_64 和 quick-sharun。现有 [Electron DEB 模板](../../Templates/quick-sharun/electron-deb.sh) 从 `package.json` 读取版本。Stacher 使用官网更新端点取得 DEB，实际版本来自该包的 control 元数据，因此沿用标准公共阶段，版本按实际包布局读取。 [官网](https://www.stacher.io/) · [AUR 配方](https://github.com/archlinux/aur/blob/stacher7/PKGBUILD)

| 构建阶段 | 专属处理与依据 |
| --- | --- |
| 安装与来源 | 公共 Arch 安装入口先安装 `stacher7` 及所需依赖，公共下载入口再从官网更新端点独立取得 DEB。解包前通过公共 DEB 接口核对 `amd64`。 [构建位置](../build_stacher.sh#L13-L27) |
| 程序与桌面资源 | 将 `usr/lib/stacher7` 完整复制到 `AppDir/bin/`，保留原生 `.node` 的文件与权限。桌面入口和图标来自同一份 DEB，修改 desktop 副本的 `Exec` 和 `Icon` 以匹配 AppImage。 [布局与桌面资源](../build_stacher.sh#L30-L35) · [图标](../build_stacher.sh#L46) |
| 运行依赖 | 在同一次 quick-sharun 调用中收集应用目录、NSS、GTK 输入模块及 ALSA、PulseAudio、PipeWire 等音频依赖。保留 GTK3、OpenGL、Vulkan、PipeWire、`STRACE_MODE=0` 和 `NO_STRIP=1`。 [部署选项](../build_stacher.sh#L54-L56) · [依赖收集](../build_stacher.sh#L68) |
| 启动与版本 | `.env` 指定包内工作目录，参数 hook 沿用原便携入口的 Chromium 参数并传递用户参数。版本取自本次 DEB 的 `Version` 字段。成品生成后沿用原有 SHA-256 文件，再通过公共入口保存 `dist/version.txt`。 [版本读取](../build_stacher.sh#L59-L62) · [启动与封装](../build_stacher.sh#L82-L96) |

相关路径及参数见[固定配置](./hardcoded.md)，验收状态见[应用说明](../README.md#变更记录)。
