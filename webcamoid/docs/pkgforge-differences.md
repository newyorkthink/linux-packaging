# Webcamoid 与 pkgforge 打包的差异

## 核对来源

本次读取 pkgforge-dev/Webcamoid-AppImage 的 main 快照 `89a76f637e440b8770468855b945b8957a2b23d7`：

- [get-dependencies.sh](https://github.com/pkgforge-dev/Webcamoid-AppImage/blob/89a76f637e440b8770468855b945b8957a2b23d7/get-dependencies.sh)
- [make-appimage.sh](https://github.com/pkgforge-dev/Webcamoid-AppImage/blob/89a76f637e440b8770468855b945b8957a2b23d7/make-appimage.sh)
- [appimage.yml](https://github.com/pkgforge-dev/Webcamoid-AppImage/blob/89a76f637e440b8770468855b945b8957a2b23d7/.github/workflows/appimage.yml)
- [README](https://github.com/pkgforge-dev/Webcamoid-AppImage/blob/89a76f637e440b8770468855b945b8957a2b23d7/README.md)

本仓库对应脚本基线为 [d1b4475](https://github.com/newyorkthink/linux-packaging/blob/d1b4475cb5ae5215a7490dd67a8210bb5eaeb552/webcamoid/build_webcamoid.sh)，实际是源码补丁、暂存安装与 quick-sharun 的组合，不是原样迁移上述上游脚本。功能结果见 [README 实机验证](../README.md#实机验证)。

## 取舍与实际代码

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| quick-sharun 收集依赖 | 采用同类公共工具；上游系统入口命令未启用 | 见下方本仓库完整收集命令及 [实际位置](https://github.com/newyorkthink/linux-packaging/blob/d1b4475cb5ae5215a7490dd67a8210bb5eaeb552/webcamoid/build_webcamoid.sh#L107) | 本仓库主程序和插件来自 work/stage，并显式加入已用辅助程序、Qt 插件和私有库；不是直接复用官方通配命令。 |
| 最终生成 AppImage | 采用公共封装步骤 | `quick-sharun --make-appimage`；[实际位置](https://github.com/newyorkthink/linux-packaging/blob/d1b4475cb5ae5215a7490dd67a8210bb5eaeb552/webcamoid/build_webcamoid.sh#L163) | 与上游使用相同工具命令；应用构建阶段和后续版本保存仍按本仓库流程。 |
| make-aur-package libuvc / webcamoid | 未启用 | 无当前执行代码；原文见下方 | 本仓库通过公共入口安装列明依赖，再独立取得正式 Release 源码并应用现有补丁。 |
| ffmpeg-mini 与 debloated 包 | 未启用 | 无上游命令；本仓库 [既有兼容处理](https://github.com/newyorkthink/linux-packaging/blob/d1b4475cb5ae5215a7490dd67a8210bb5eaeb552/webcamoid/build_webcamoid.sh#L11) | 当前先移除 ffmpeg-mini，再安装完整 ffmpeg；保留已有录制和软件编码路线。 |
| GStreamer 部署 | 未启用 | 上游 DEPLOY_GSTREAMER=1 未启用；本仓库当前值为 0，CMake 使用 NOGSTREAMER=ON | 与本应用 [原有后端错误记录](./error.md#gstreamer) 对应，不恢复上游依赖包组。 |
| 自更新 hook | 未启用 | ADD_HOOKS 未出现在当前构建脚本中 | 上游 README 说明提供自更新；本仓库保持既有 Release 发布与版本清单机制，不加入该 hook。 |
| zsync 更新信息 | 未启用 | UPINFO 未出现在当前构建脚本中 | 保留本仓库固定资产名与版本元数据接口，不引入另一组更新资产。 |
| 系统图标和 desktop 路径 | 未启用 | 上游路径未启用；本仓库从源码选择图标并生成 work/webcamoid.desktop | 当前没有安装系统 webcamoid 包，桌面资源采用当前源码流程。 |
| 双架构 workflow 与上游 release Action | 未启用 | 使用本仓库已有 .github/workflows/build.yml 和 webcamoid 清单项 | 当前仅 x86_64，使用既有独立 matrix 运行与逐项发布流程。 |

### 本仓库实际收集命令

位置：[build_webcamoid.sh](https://github.com/newyorkthink/linux-packaging/blob/d1b4475cb5ae5215a7490dd67a8210bb5eaeb552/webcamoid/build_webcamoid.sh#L107)。

```bash
# 收集程序及其运行依赖。
quick-sharun work/stage/bin/webcamoid /usr/bin/ffmpeg /usr/bin/ffprobe /usr/bin/v4l2-ctl "${STAGE_SHARED_OBJECTS[@]}" "${QT_RUNTIME_PLUGINS[@]}" "${PRIVATE_RUNTIME_LIBS[@]}"
```

### 上游命令原文

以下只保存已读快照，不是当前启用步骤，不作为恢复指令。

依赖脚本中的精简包与 AUR 应用安装：

```sh
get-debloated-pkgs --add-common --prefer-nano ffmpeg-mini
make-aur-package libuvc
make-aur-package webcamoid
```

封装脚本：

```sh
export ADD_HOOKS="self-updater.bg.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/256x256/apps/webcamoid.png
export DESKTOP=/usr/share/applications/webcamoid.desktop
export DEPLOY_GSTREAMER=1

# Deploy dependencies
quick-sharun \
  /usr/bin/webcamoid \
  /usr/lib/qt/plugins/avkys/*

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage
```

上游 README 明确说明自更新用途；其他上述包选择、编码器覆盖和 GStreamer 取值的专属理由，所读文件没有进一步解释，官方未说明原因。表中的本仓库取舍依据属于本仓库当前实现与已有记录，不冒称官方原始理由。

后续拟采用其中某一未启用处理时，重新核对对应上游当前实现及本应用需求，不直接恢复本页历史快照。
