# Visual Studio Code AppImage

## 用途与产物

本目录从 Microsoft 官方稳定版 Linux x64 tar 包构建 `dist/vscode.AppImage`。

## 技术栈与打包方式

Visual Studio Code 为 Electron / Chromium 桌面应用。构建脚本动态解析 Microsoft stable 下载地址，保留官方程序目录，读取官方 desktop 与 URL handler，并通过 quick-sharun 收集 GTK3、NSS、X11、OpenGL 和 IBus 运行依赖。

## 运行

```bash
./dist/vscode.AppImage
```

## 版本元数据

版本从官方程序目录 `resources/app/package.json` 读取，并继续写入 desktop 的 `X-AppImage-Version`。构建完成后同一版本写入 `dist/version.txt`，workflow 使用 `SOFTWARE_KEY=vscode` 接入统一清单。

## 官方代码复用

上游打包来源为 [pkgforge-dev/Visual-Studio-Code-AppImage](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage)，本次核对固定在 [`0016f8465bfeb37d7bb557eeab0c8469a41cf0de`](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/commit/0016f8465bfeb37d7bb557eeab0c8469a41cf0de)。

- [get-dependencies.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/get-dependencies.sh)：原样保留删除 `copilot-linuxmusl-x64` 的命令。官方仅以 `# not needed` 标记无需保留，未说明进一步技术原因；本仓库将这条简略注释改成清楚的中文用途说明，不改变命令。
- [make-appimage.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/make-appimage.sh)：原样保留 `DEPLOY_OPENGL=1` 和 `DEPLOY_VULKAN=1`，用于收集相应图形运行依赖。官方未说明额外背景原因。
- [cli-router.hook](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/AppDir/bin/cli-router.hook)：保留上游命令行入口、远程终端转发、WSL 提示和 root 启动检查的完整代码。文件头补充同一上游的版权及 MIT 许可注释，可执行代码和原有运行提示不改。

图标、主 desktop 和 URL 协议入口文件直接从已安装的 `visual-studio-code-bin` 获取，不下载 desktop 模板，也不替换占位符。这部分属于本仓库的标准资源获取流程，不标注为官方原命令。

详细出处、用途及原因见 [模板差异说明](./docs/template-deviations.md)；固定路径及参数依据见 [固定配置说明](./docs/hardcoded.md)。

## 变更记录

### 2026-10-29：按标准模板整理并复用官方专属代码

通过公共入口安装依赖、下载及解包官方稳定版 tar 包、读取版本和保存最终版本；保留完整程序目录、包内中文 locale 和原有图形部署选项。主 desktop 直接使用系统安装包提供的 `/usr/share/applications/com.microsoft.VSCode.desktop`，协议入口同样取自该安装包。

删除组件的命令及命令行路由代码按固定上游版本复用。将过于简略的删除注释改成中文说明，同步补充来源、用途、官方原因和固定配置记录。提交前完成 Bash 语法、ShellCheck、官方代码一致性及文档检查；未执行真实应用构建或图形界面验收。

### 2026-09-16：接入统一软件版本元数据

仅增加更新器版本文件与统一发布映射，不改变 Microsoft stable 下载、Electron 目录、URL handler 或 quick-sharun 基线。

ShellCheck 沿用标准模板中 `export ARCH="$(uname -m)"` 的既有 SC2155 格式提示，不为消除此提示拆分已确认的模板命令。
