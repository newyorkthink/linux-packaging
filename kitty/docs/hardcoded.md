# kitty 固定配置与故障依据

## 保留的运行基线

本次以 [65850a8 中的原脚本](https://github.com/newyorkthink/linux-packaging/blob/65850a8e11bad58bcf30fac33dae6dc20dd31be9/kitty/build_kitty.sh) 为基线。下面的路径和参数都是既有实现，不因拆分文件而更换；原 `AppRun` 的 169 行正文逐字保存到 [AppRun](../AppRun)。

| 既有配置 | 用途与保留依据 |
| --- | --- |
| `AppDir/usr/lib/kitty.app` | 保持官方预编译包的 bin、lib、share 相对布局，与现有启动路径一致。 |
| `bin/kitty`、`bin/kitten` | 普通入口运行 kitty；启动名称为 `kitten` 时运行包内 `kitten`，并原样传递参数。 |
| `share/terminfo/x/xterm-kitty` | 沿用 Arch `kitty-terminfo` 的已编译数据库；不调用 tic，也不改终端类型。 |
| `libxcb-xkb.so.1` | 保留既有 X11 GLFW 运行依赖复制步骤和缺库判断。 |
| `XMODIFIERS=@im=fcitx`、`GLFW_IM_MODULE=ibus` | 保留已有 Fcitx5 / IBus 接入逻辑；GLFW_IM_MODULE 仍只在地址就绪后设置。 |
| 80 次、每次 0.25 秒、稳定 12 次 | 保留开机自启时最长约 20 秒的等待与连续稳定约 3 秒的判断。 |
| `ARGV0`、`APPIMAGE`、`TMUX`、`TMUX_PANE` | 保留启动名称识别；普通 kitty 隔离父级 tmux 环境，`kitten` 分支不执行该隔离。 |
| `kitty.AppImage`、`dist/version.txt` | 保持正式资产名和现有 workflow 的版本元数据接口。 |

这些历史配置的首次故障日志未保存在 kitty 目录，不能把本次整理描述为重新修复了这些功能。本次只保留既有行为，并单独记录下面实际取得的图标封装错误。

## 2026-11-01：PNG `.DirIcon`

故障来源：[Build kitty](https://github.com/newyorkthink/linux-packaging/actions/runs/41263573517/job/124733830935)，构建提交为 65850a8e11bad58bcf30fac33dae6dc20dd31be9。

以下为这次图标故障对应的完整报错正文，省略 GitHub Actions 时间戳：

~~~text
appimagetool, continuous build (git version 9bab981), build 340 built on 2026-10-31 09:33:46 UTC
ERROR: /__w/linux-packaging/linux-packaging/kitty/AppDir/.DirIcon
       Problem: .DirIcon is an SVG image (/__w/linux-packaging/linux-packaging/kitty/AppDir/kitty.svg). SVG is hard to parse, so file managers and thumbnailers cannot be expected to handle it; .DirIcon must be a PNG
       Fix:     convert it to a PNG with 'rsvg-convert -w 256 -h 256 '/__w/linux-packaging/linux-packaging/kitty/AppDir/kitty.svg' -o '/__w/linux-packaging/linux-packaging/kitty/AppDir/kitty.png'' (or ImageMagick/Inkscape) and delete the SVG .DirIcon with 'rm '/__w/linux-packaging/linux-packaging/kitty/AppDir/.DirIcon''; appimagetool then creates .DirIcon from kitty.png
appimagetool: no AppImage was created because .DirIcon is not valid.
##[error]Process completed with exit code 1.
~~~

desktop 继续使用 `Icon=kitty`。资源准备末尾调用既有 `common/appimage/prepare_appdir_for_appimagetool.sh`，优先使用包内同名 PNG；SVG 仍可保留作为应用图标。随后把 `.DirIcon` 明确链接到 `kitty.png`，避免最终封装继续读到 SVG。

上面的构建号只用于记录故障，不用于固定工具版本。`appimagetool` 和 `Type 2 runtime` 的原 `continuous` 下载入口保持不变。

## 2026-11-01：公共封装替代手工图标链接

本节说明当前实现。前述资源阶段手工设置 `.DirIcon` 的方式属于 [7813f09](https://github.com/newyorkthink/linux-packaging/commit/7813f09eb577e2c985c1b22f781286dad159a0b4) 的修复记录，本次由公共封装流程替代，原故障正文继续保留。

| 保留的配置 | 当前获取或处理方式 | 影响 |
| --- | --- | --- |
| 官方 installer URL、`/tmp/kitty-installer.sh` | 公共下载入口取得脚本，随后执行原 installer 命令。 | 不变更官方程序来源或包内布局。 |
| 官方 appimagetool continuous URL、`/tmp/appimagetool` | 公共下载入口取得工具，再沿用原 `chmod +x`。 | 不固定旧版本，也不引入另一套下载重试。 |
| 官方 Type 2 runtime continuous URL、`/tmp/runtime-x86_64` | 公共下载入口取得 runtime，再沿用原 `chmod +x`。 | 最终封装仍明确使用该 runtime。 |
| `Icon=kitty`、`kitty.png`、`.DirIcon` | 资源脚本只复制图标，公共封装入口负责取得 PNG，appimagetool 创建最终链接。 | 避免预先创建 SVG `.DirIcon`；PNG 准备只调用一次。 |
| `dist/version.txt` | 软件版本作为第五参数传入公共封装入口；产物非空时才保存版本。 | 保持版本文件位置和内容格式，移除调用方重复保存。 |

本次未新增应用版本、下载地址或运行时环境的固定值；原 AppRun 及 kitten 分派保持不变。

## 2026-11-01：版本与封装工具参数统一交给公共入口

本节接续上面的公共封装记录。官方 installer、AppDir 布局、两个封装工具的输出路径及 AppRun 均保持原样。

- 版本来源仍是 `AppDir/usr/lib/kitty.app/bin/kitty --version` 的首行第二字段。字段 2 来自原有 awk 取值；原正则原样迁入公共 `command` 来源，不更换取值规则。
- 两个输出文件仍是 `/tmp/appimagetool` 和 `/tmp/runtime-x86_64`。工具准备入口的 `--appimagetool` 模式统一查询原官方 continuous Release、校验当次资产 SHA-256，并设置执行权限；不写死版本或摘要。
- 主脚本只传入两个输出路径，不再重复官方工具 URL、下载和 chmod 命令；不执行 linuxdeploy，也不追加重复成功提示。
- 旧直接下载和手工版本解析的说明作为前面提交的历史保留，当前调用以本节及 README 的“当前公共入口”为准。原图标故障正文继续保留。

## 2026-11-08：官方预编译包下载入口调整

原构建脚本下载官方 `installer.sh` 并交由安装器内部获取预编译包。此次故障来自 [Build kitty](https://github.com/newyorkthink/linux-packaging/actions/runs/42475221749/job/128714966257)：安装器内部请求 GitHub Release 的 `kitty-0.50.0-x86_64.txz` 返回 HTTP 504。

当前构建脚本不再下载或运行安装器，而是通过 GitHub 官方最新 Release 标签确定 `kitty-{version}-x86_64.txz` 资产，复用公共固定资产名下载脚本取得并校验官方 SHA-256，然后直接解压到原有 `AppDir/usr/lib/kitty.app`。版本动态获取，不固定版本、资产 ID、摘要或历史下载地址。公共下载脚本沿用原有直链优先和失败后认证回退机制。

本节更新的是上文“官方 installer URL、`/tmp/kitty-installer.sh`”和“官方 installer 保持原样”的当前适用性；上文既有配置、图标故障原始记录、历史构建说明及原 `AppRun` 均保留。
