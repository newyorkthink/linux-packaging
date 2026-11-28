# AionUi 模板差异

AionUi 采用 Arch Linux x86_64 和 quick-sharun。现有 [Electron DEB 模板](../../Templates/quick-sharun/electron-deb.sh) 从 DEB 直链下载并从 `package.json` 读取版本。AionUi 使用官网更新清单中同一条资产的文件名、SHA-512 和版本，因此沿用标准公共阶段，下载和版本读取接入已有公共接口。官网发布流程将安装包放在版本目录，将渠道清单放在发布根目录。 [官方发布流程](https://github.com/iOfficeAI/AionUi/blob/e108b6b56b1a6eb99a00904878d0582f657b2908/.github/workflows/release-distribute.yml#L108-L167)

| 构建阶段 | 专属处理与依据 |
| --- | --- |
| 安装与来源 | 公共 Arch 安装入口先安装 `electron37-bin`，再通过 `--replace zlib-ng-compat` 将容器默认的 `zlib` 替换为 `aioncore-bin` 要求的 `zlib-ng-compat`（避免 `yay -S --noconfirm` 事务冲突），随后安装 `aionui-bin`、DEB 工具和 `python-yaml`。公共 Electron 清单入口独立从官网下载并校验 DEB，成功后把版本写入 `work/source-version.txt`。解包前通过公共 DEB 接口核对 `amd64`。 [构建位置](../build_aionui.sh#L12-L31) · [AUR 配方](https://github.com/archlinux/aur/blob/aionui-bin/PKGBUILD) · [AionCore 配方](https://aur.archlinux.org/packages/aioncore-bin) · [前次 Electron 报错日志](https://github.com/newyorkthink/linux-packaging/actions/runs/46135198313/job/140948851645) · [zlib 冲突日志](https://github.com/newyorkthink/linux-packaging/actions/runs/46139316468/job/140961556469) |
| 程序与桌面资源 | 将 `opt/AionUi` 完整复制到 `AppDir/bin/`，保留原生 `.node` 的文件与权限。使用同一份 DEB 中的 desktop 和包内图标，构建副本的 `Exec` 和 `Icon` 指向成品入口及图标，保留 desktop 的协议字段。 [构建位置](../build_aionui.sh#L34-L39) · [官方打包配置](https://github.com/iOfficeAI/AionUi/blob/e108b6b56b1a6eb99a00904878d0582f657b2908/packages/desktop/electron-builder.yml) |
| 运行依赖 | 在同一次 quick-sharun 调用中收集应用目录、内置 AionCore 和既有的音频、NSS、GTK 输入模块。保留 GTK3、OpenGL、Vulkan、PipeWire、`STRACE_MODE=0` 和 `NO_STRIP=1`。 [构建位置](../build_aionui.sh#L58-L69) |
| 启动与版本 | `.env` 指定包内工作目录，参数 hook 沿用原便携入口的 Chromium 参数并传递用户参数。版本从同次清单记录读取，成品成功生成后由公共入口写入 `dist/version.txt`。 [版本读取](../build_aionui.sh#L63) · [启动与封装](../build_aionui.sh#L83-L94) |

相关路径及参数见[固定配置](./hardcoded.md)，验收状态见[应用说明](../README.md#验证状态)。
