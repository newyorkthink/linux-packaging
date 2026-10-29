# Cursor AppImage

## 用途与产物

本目录从 Cursor 官方 Linux x64 DEB 动态下载当前版本，并通过 quick-sharun 重新封装为 `dist/cursor.AppImage`。

## 技术栈与打包方式

Cursor 属于 Electron / VS Code 系谱。构建脚本安装 AUR `cursor-bin` 及其依赖，另行下载当前官方 x64 DEB，解包后把整个程序目录放进 `AppDir/bin`。图标和 desktop 直接使用 AUR 安装结果，由 quick-sharun 放进包，不再复制到脚本目录或改写 `Exec`、`Icon`。GTK 3 输入模块由 quick-sharun 收集。包内带有 zh_CN.UTF-8。

图标使用 `/usr/share/pixmaps/co.anysphere.cursor.png`，桌面入口使用 `/usr/share/applications/cursor.desktop`，具体依据见 [docs/hardcoded.md](docs/hardcoded.md)。构建脚本中可复用的注释与 WorkBuddy 使用相同表述。脚本在 `APPNAME` 后通过 `MAIN_BIN=cursor` 显式指定主程序，与 WorkBuddy 的设置位置、注释和相邻空行保持一致。

## 运行

```bash
./dist/cursor.AppImage
```

## 版本元数据

版本从官方包内 `resources/app/package.json` 读取。现有 `X-AppImage-Version` 逻辑继续保留，改为检查 `DESKTOP` 指向的系统安装文件，缺少该字段时向同一文件追加版本；这一步只发生在 CI 构建环境中。构建完成后同一版本额外写入 `dist/version.txt`，workflow 使用 `SOFTWARE_KEY=cursor` 接入统一清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加 `dist/version.txt` 与发布映射；官方 DEB 解析、Electron 目录、desktop、IBus/NSS 与 quick-sharun 逻辑保持不变。

### 2026-10-29：按 Electron 目录方式重排构建脚本

官方 x64 deb 改由 download_file.sh 从当前下载地址取得，再用 extract_archive.sh 解包。整个程序目录放进 AppDir/bin。脚本不再逐个传入 NSS、pkcs11 和输入模块。包内增加中文 locale。提交 7d92a907c379a0e0c0cf405948726d9fd39b770b。

### 2026-10-29：复用已安装的图标和桌面入口

- 原因：构建已安装 `cursor-bin`，可以直接使用安装结果中的图标和 desktop，原有的本地复制和 `Exec`、`Icon` 改写不再需要。
- 修改文件：`cursor/build_cursor.sh`、`cursor/README.md`、`cursor/docs/hardcoded.md`。
- 修改内容：`ICON`、`DESKTOP` 改为系统安装路径，删除两条资源复制命令和整段 desktop 修正，移除不再生成的本地资源清理项；版本字段的检查和追加同步改用 `"$DESKTOP"`。安装、下载、复制、GTK 部署、版本读取及依赖收集的通用注释与 WorkBuddy 对齐，注释位置和相邻空行逐处核对。程序来源、版本解析、quick-sharun 参数和中文环境保持原样。
- 已知结果：提交前完成 Bash 语法、路径引用、通用注释和空行及完整差异核对；本次未构建或启动修改后的 AppImage。

### 2026-10-29：显式指定主程序入口

按用户要求，在 `APPNAME=Cursor` 后补上通用注释及 `export MAIN_BIN=cursor`，设置位置和空行与 WorkBuddy 对齐。quick-sharun 直接使用该入口文件名，其他构建命令和参数保持原样。固定入口的依据同步记录在 [docs/hardcoded.md](docs/hardcoded.md)。提交前完成 Bash 语法、插入位置和完整差异核对；本次未构建或启动修改后的 AppImage。
