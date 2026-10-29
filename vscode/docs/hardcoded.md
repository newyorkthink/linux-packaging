# 固定配置说明

本文件记录当前应用固定值的来源、用途和影响。构建路线及官方复用代码见 [模板差异说明](./template-deviations.md)，维护入口见 [README](../README.md)。

## 下载与程序目录

| 固定值 | 依据与用途 |
| --- | --- |
| `https://code.visualstudio.com/sha/download?build=stable&os=linux-x64` | 本应用原有的 Microsoft 官方稳定版 Linux x64 tar 下载入口；公共下载脚本跟随官方重定向。 |
| `vscode.tar.gz`、`vscode-unpacked` | 当前应用目录内的下载和解包工作路径，由构建脚本统一清理和重建。 |
| `vscode-unpacked/VSCode-linux-x64/.` | 当前 x86_64 路线的官方程序目录；完整复制到 `AppDir/bin/`，保留相邻库、资源和原有启动文件。 |
| `AppDir/bin/resources/app/package.json` | 官方程序保存版本的位置；上游 [get-dependencies.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/get-dependencies.sh) 使用同一路径。 |

## 安装包提供的桌面元数据

本次已读取核对 [Microsoft 1.144.0 官方安装包](https://vscode.download.prss.microsoft.com/dbazure/download/stable/2c33b50b16c472efe58357d1d2a8a5414bc23fbf/code_1.144.0-1793133881_amd64.deb) 内的 desktop、图标和 `resources/app/product.json` 元数据，没有安装或运行该程序。[AUR 打包文件](https://github.com/archlinux/aur/blob/visual-studio-code-bin/PKGBUILD) 将官方 DEB 的文件安装到系统目录。

| 固定值 | 依据与用途 |
| --- | --- |
| `APPNAME=Code`、`MAIN_BIN=code` | 保留当前应用名与真实主程序名；官方 [cli-router.hook](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/AppDir/bin/cli-router.hook) 也调用 `AppDir/bin/code`。 |
| `STARTUPWMCLASS=com.microsoft.VSCode` | 与本次核对的官方 desktop 和 `product.json` 中的窗口类名称一致。 |
| `ICON=/usr/share/pixmaps/vscode.png` | 使用已安装软件包提供的图标，取值与官方安装包一致，不自行制作图标。 |
| `DESKTOP=/usr/share/applications/com.microsoft.VSCode.desktop` | 直接使用已安装软件包提供的完整主 desktop，不下载模板，不替换占位符。 |
| `/usr/share/applications/com.microsoft.VSCode.UrlHandler.desktop` | 已安装软件包的协议入口来源；在产物内保留为 `AppDir/share/applications/code-url-handler.desktop`。 |

以上是本应用在本次核对中的实际配置，不是面向任意应用的通用示例。后续维护仍须按对应软件包的真实布局核对。

## 官方专属路径与文件

| 固定值 | 依据与用途 |
| --- | --- |
| `AppDir/bin/resources/app/node_modules/@github/copilot-linuxmusl-x64` | [官方 get-dependencies.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/get-dependencies.sh) 明确删除此目录；命令逐字复用。原注释只说明不需要保留，官方未说明进一步原因。 |
| `vscode/cli-router.hook` | 本仓库保存上游配套文件的路径，文件代码逐字保留，仅在文件头补充官方许可注释。 |
| `AppDir/bin/cli-router.hook` | [上游配套文件的原有位置](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/AppDir/bin/cli-router.hook)；在最终封装前放入构建目录。 |

## 产物与版本输出

- `OUTPATH="$SCRIPT_DIR/dist"` 与 `OUTNAME=vscode.AppImage` 对应统一清单中的 `vscode/dist` 和 `vscode.AppImage`。
- 构建版本继续写入 CI 构建 HOME 下的 `version`；这不是在最终 AppImage 中写死宿主用户路径。
- 主 desktop 和协议入口缺少 `X-AppImage-Version` 时由公共版本入口追加；已有字段继续按原有规则保留。
- 最终产物生成后保存 `dist/version.txt`，由现有 workflow 使用 `SOFTWARE_KEY=vscode` 更新版本清单。

本次是按已确认方案整理代码和说明，没有以新故障为由添加额外路径或参数。
