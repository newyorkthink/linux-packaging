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

## 实机验证

### 2026-11-28：用户实机验证通过

已由用户在 Linux 实机核对 [Build SimpleScreenRecorder](https://github.com/newyorkthink/linux-packaging/actions/runs/46116396819/job/140891138938) 生成的 `simplescreenrecorder.AppImage`（Qt `6.12.1`，`libavformat 63.16.100`、`libavcodec 63.24.100`、`libavutil 61.19.100`、`libswscale 10.5.100`）及其解包目录：

- 包内布局核对：包含 `.env`（中文 UTF-8 与 `LOCPATH`）、`bin/01-path-mapping-hardcoded.hook`、`bin/qt.conf`、`lib/qt6/plugins/{platforminputcontexts,platformthemes,styles}`、`lib/locale/zh_CN.utf8` 与 `share/simplescreenrecorder/translations/*.qm`。

| 实测项目 | 通过结果 |
| --- | --- |
| 中文界面与 Qt6 运行时 | 主界面、输入/输出设置页、录制控制页及控制台日志全中文显示，实际加载 Qt `6.12.1`。 |
| Fcitx5 中文输入 | 参数输入框与“另存为”文件输入框均可正常弹出 Fcitx5 中文候选窗并输入中文字符。 |
| X11 屏幕与音频采集 | X11 共享内存全屏录制（`1920x1080`）及 PulseAudio / ALSA 音频源枚举与采集正常，实时预览画面和电平表可用。 |
| 编码导出、回放与目录打开 | 使用 `libx264`（30.000 FPS）与 `libvorbis` 导出含中文文件名的 MP4（`1.06 MiB`），MediaInfo 检测视频流（`1920x1080`）完整，外部播放器回放正常，“打开文件夹”可在浏览器中打开输出目录。 |

#### 运行观察

- 停止录制关闭复用器时终端提示 `[Muxer::Free] 错误：无法写入 tailer，将继续下一步。`，已导出的 MP4 文件可正常校验与播放，不阻断录制。
- 点击“打开文件夹”时宿主缺少 `inode/directory` 默认应用与 `x-www-browser`（提示 `No applications found for mimetype: inode/directory` 与 `./usr/bin/xdg-open: 1032: x-www-browser: not found`），随后仍通过浏览器打开目录列表，属于宿主默认应用配置行为。
- **结论**：当前 `build_simplescreenrecorder.sh` 无需补充依赖或修改构建逻辑，保持为已验证基线。

## 变更记录

### 2026-11-28：按标准模板整理并迁移至 Qt6

按 [qt-installed.sh](../Templates/quick-sharun/qt-installed.sh) 重写 [build_simplescreenrecorder.sh](./build_simplescreenrecorder.sh)，核实 AUR 当前构建已切换为 Qt6，移除旧 Qt5 依赖包并接入公共安装、工作区、版本读取与版本保存入口，保留 `STARTUPWMCLASS="simplescreenrecorder"` 与 `DEPLOY_OPENGL=1`，新增 [模板差异说明](./docs/template-deviations.md)。

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变 Qt5、音视频、Fcitx5、OpenGL 或 quick-sharun 打包逻辑。
