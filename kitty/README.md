# kitty AppImage

## 用途与产物

本目录使用 kitty 官方 Linux 预编译包构建 `dist/kitty.AppImage`，并保留 `kitten` 分派、xterm-kitty terminfo 与现有输入法运行逻辑。

## 技术栈与打包方式

kitty 为 GPU 加速终端，主体由 C/Python 组件组成。构建脚本通过官方 installer 下载完整程序目录，补入 Arch `kitty-terminfo` 与 `libxcb-xkb`，自定义 AppRun 处理 terminfo、kitten、Fcitx5/IBus 与 tmux 环境，再使用 appimagetool + Type 2 runtime 生成 AppImage。

## 运行与兼容说明

```bash
./dist/kitty.AppImage
```

现有 X11/Fcitx5 地址处理、terminfo、kitten 软链接和 tmux 环境隔离逻辑保持不变。

## 版本元数据

构建脚本从本次官方 kitty 程序的 `kitty --version` 输出解析版本，并在现有构建流程结束后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=kitty` 接入统一清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本解析与发布元数据，不改变 kitty 官方包、AppRun、输入法、terminfo 或 appimagetool 基线。
