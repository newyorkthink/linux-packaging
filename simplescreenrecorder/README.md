# SimpleScreenRecorder AppImage

## 用途与产物

本目录将当前 AUR `simplescreenrecorder` 打包为 `dist/simplescreenrecorder.AppImage`。

## 技术栈与打包方式

`pkgforge-dev` 无对应的独立打包仓库；Arch Linux 官方仓库已不再提供该软件包，官方 GitHub（`MaartenBaert/ssr`）与官网均不提供预编译二进制安装包，AUR 当前由 `simplescreenrecorder`（以 `-DWITH_QT6=TRUE -DWITH_QT5=FALSE` 编译）提供 Qt6/C++ 原生程序。

构建脚本按 [qt-installed.sh](../Templates/quick-sharun/qt-installed.sh) 整理，归入 [打包分类](../Docs/packaging-classification.md)，并保留两项原脚本既有配置（详情见 [模板差异说明](./docs/template-deviations.md)）：

1. 通过 `Common/arch/install_packages.sh --base` 安装统一打包基础包，再安装 AUR `simplescreenrecorder`、模板固定的 Qt6 输入与主题插件（`fcitx5-qt`、`qt6ct`、`kvantum`、`lxqt-qtplugin`）及原有非 Qt5 音视频、X11、OpenGL 运行依赖，并由 `Common/build/prepare_x86_64_workspace.sh` 清理工作区。
2. 设置 `ARCH`、`STARTUPWMCLASS="simplescreenrecorder"`、`ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME="simplescreenrecorder.AppImage"`、`DEPLOY_OPENGL=1` 与 `DEPLOY_QT=1`。
3. 通过 `Common/build/read_app_version.sh` 读取本次实际安装的 `simplescreenrecorder` 版本，调用 `quick-sharun /usr/bin/simplescreenrecorder` 收集依赖，并按模板生成包内 `zh_CN.utf8` locale。
4. `quick-sharun --make-appimage` 生成固定文件名 `dist/simplescreenrecorder.AppImage`，成功后由 `Common/build/save_appimage_version.sh` 校验产物并写入 `dist/version.txt`。

## 运行

```bash
./dist/simplescreenrecorder.AppImage
```

实际录制能力仍取决于宿主音频、显示服务器、编码器与图形环境。

## 版本元数据

构建时由公共入口读取本次实际安装的 AUR `simplescreenrecorder` 版本，去掉 epoch 与 pkgrel 后在最终封装成功时写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=simplescreenrecorder` 接入统一清单。

## 变更记录

### 2026-11-28：按标准模板整理并迁移至 Qt6

按 [qt-installed.sh](../Templates/quick-sharun/qt-installed.sh) 重写 [build_simplescreenrecorder.sh](./build_simplescreenrecorder.sh)，核实 AUR 当前构建已切换为 Qt6，移除旧 Qt5 依赖包并接入公共安装、工作区、版本读取与版本保存入口，保留 `STARTUPWMCLASS="simplescreenrecorder"` 与 `DEPLOY_OPENGL=1`，新增 [模板差异说明](./docs/template-deviations.md)。

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变 Qt5、音视频、Fcitx5、OpenGL 或 quick-sharun 打包逻辑。
