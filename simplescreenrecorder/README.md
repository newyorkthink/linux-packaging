# SimpleScreenRecorder AppImage

## 用途与产物

本目录将 Arch Linux 当前稳定 SimpleScreenRecorder 打包为 `dist/simplescreenrecorder.AppImage`。

## 技术栈与打包方式

SimpleScreenRecorder 为 Qt5/C++ 屏幕录制程序。构建脚本安装音视频、X11、OpenGL、Qt5 与 Fcitx5 相关运行组件，通过 quick-sharun 收集 `/usr/bin/simplescreenrecorder` 并生成固定资产。

## 运行

```bash
./dist/simplescreenrecorder.AppImage
```

实际录制能力仍取决于宿主音频、显示服务器、编码器与图形环境。

## 版本元数据

构建时从本次实际安装的 Arch `simplescreenrecorder` 包读取版本，去掉 epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=simplescreenrecorder` 接入统一清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变 Qt5、音视频、Fcitx5、OpenGL 或 quick-sharun 打包逻辑。
