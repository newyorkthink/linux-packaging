# ChatGPT 官方处理判断

核对日期：2026-10-30。参考 [pkgforge-dev/ChatGPT-Desktop-AppImage](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage)，固定 commit：`0e52cadeafc0229ea9a55415a70a2abc00d0bf07`。应用身份与本仓库一致，均来自 OpenAI 官方 Linux ChatGPT DEB。

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 删除 Qt shim | 采用并逐字复用 | `rm -f ./AppDir/bin/libqt*_shim.so`；[构建位置](../build_chatgpt.sh#L31) | 避免全目录收集额外处理 Qt 依赖；删除范围为打包副本。上游对 Electron 是否实际使用这些适配模块尚有保留，Plasma 主题/窗口装饰效果列为待测试，不能写成模块已被证明完全无用。 |
| 全目录收集 | 采用并逐字复用 | `quick-sharun ./AppDir/bin/*`；[构建位置](../build_chatgpt.sh#L56) | 使用当前工具默认依赖检测，取代旧脚本自定义 ELF 循环和手工库路径。官方未说明选择该命令的更多原因。 |
| 下载、解包和搬运 | 官方命令未启用，采用标准公共入口 | [下载](../build_chatgpt.sh#L20-L22)、[解包和复制](../build_chatgpt.sh#L25-L28) | AUR 元数据提供同源官方地址与摘要；复用公共安装、下载、解包，不复制官方 wget/ar/tar/mv 命令。 |
| desktop、图标及小写链接 | 官方命令未启用，采用标准元数据 | [MAIN_BIN](../build_chatgpt.sh#L38)、[系统资源](../build_chatgpt.sh#L42-L44) | MAIN_BIN 直接指定真实 ChatGPT 程序；系统资源交工具收集，不另加官方的小写名称链接或桌面复制段。 |
| 自动更新与 namespace hook | 未启用 | 正式构建不设置 ADD_HOOKS。 | 不新增运行时自更新或宿主 namespace 调整；保留本仓库已有宿主 bwrap PATH 与启动参数。官方未说明这两项 hook 的选择原因。 |
| STRACE_BINARY 与官方测试 | 未启用 | 正式构建不设置该变量，也不调用 --test。 | 依标准使用工具默认收集，移除旧内联自测，不把上游 CI 测试参数当成用户启动参数的依据。 |

## 原文与原因

Qt 删除原文来自 [get-dependencies.sh](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage/blob/0e52cadeafc0229ea9a55415a70a2abc00d0bf07/get-dependencies.sh)：

```sh
rm -f ./AppDir/bin/libqt*_shim.so
```

上游注释表示这些模块通常用于 Chromium 跟随系统主题，作者此前未见 Electron 使用，并保留 Plasma 下主题/窗口装饰测试 TODO。这是上游实际说明；“全目录输入会额外引入 Qt 依赖”是本次结合 [Chromium Qt 构建源码](https://github.com/chromium/chromium/blob/main/ui/qt/BUILD.gn) 和 [quick-sharun](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh) 作出的技术判断，不冒充上游已经完成的兼容性验证。

收集原文来自 [make-appimage.sh](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage/blob/0e52cadeafc0229ea9a55415a70a2abc00d0bf07/make-appimage.sh)：

```sh
quick-sharun ./AppDir/bin/*
```

两条采用的命令保持原文，只补充中文用途注释。以下记录相关未采用原文，不作为当前执行代码。

准备脚本中由标准公共入口及元数据配置替代的命令：

```sh
DEB_LINK=https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_$farch.deb
wget --retry-connrefused --tries=30 "$DEB_LINK" -O /tmp/temp.deb
ar xvf /tmp/temp.deb
tar -xvf ./data.tar.xz
mv -v ./usr/lib/chatgpt/* ./AppDir/bin
ln -sv ChatGPT ./AppDir/bin/chatgpt || :
cp -v ./usr/share/applications/chatgpt.desktop ./AppDir
cp -v ./usr/share/pixmaps/chatgpt.png          ./AppDir
cp -v ./usr/share/pixmaps/chatgpt.png          ./AppDir/.DirIcon
```

封装脚本中未启用的配置与测试命令：

```sh
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export STRACE_BINARY=$(find ./AppDir/bin -maxdepth 1 -type f -executable | grep -v '\.so')
quick-sharun --test ./dist/*.AppImage --no-sandbox
```

已有宿主 bwrap 与启动参数是本仓库原处理，不标为 pkgforge 原命令。

本次没有重新下载安装包、打包或实机测试。官方删除步骤也不能替代本应用在 Plasma 或 Codex 各功能上的实测。
