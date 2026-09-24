# 已知隐患

这个目录只记已经看过、暂时不改代码的打包问题和隐患。

这里有记录，不表示要去改对应构建脚本。真要改某个应用时，单独处理那个应用。

| 事项 | 决定 | 说明 |
| --- | --- | --- |
| quick-sharun 的 Mesa / LLVM 红字 | 保留 | 原文未改，见 [quick-sharun-mesa-llvm-explanation.md](./quick-sharun-mesa-llvm-explanation.md) |
| 从 i3wm AppImage 再启动别的程序 | 先不改别的包 | 有时起不来。WPS 上见过，见 [i3wm-appimage-child-launch.md](./i3wm-appimage-child-launch.md) |

红字是 `WARNING: Detected the bundled libgallium links to libLLVM.so!`。quick-sharun 收进 `libgallium` → `libLLVM` 时自己打印。没有开关。库留着，这行就在。它不是构建失败，带上这些库也能启动。代价是包变大，而且这是构建机的 Mesa 驱动，换显卡或旧内核可能不兼容。

## Discord 代码核对

2026-09-24 核对 `discord/build_discord.sh`：

- 已经没有删除 `libgallium*`、`libLLVM*`、`libGLX_mesa*` 的 `find -delete`。
- 已经没有删库之后的 `sharun -g`。
- `DEPLOY_OPENGL=0` 和 `DEPLOY_VULKAN=0` 还在。这两个开关挡不住动态扫描把上述库收进去。
- `bash -n` 通过。

这次核对没有改 Discord 脚本。

随后按用户要求去掉 `DEPLOY_OPENGL=0` 和 `DEPLOY_VULKAN=0`。这两个开关是用来挡构建机 Mesa 的，不是删库代码。`NO_STRIP=1` 仍保留。红字决定不变。

更正：上面这句理解错了。要去掉的是删除 `libLLVM` 的代码，Discord 脚本里已经没有。`DEPLOY_OPENGL=0` 和 `DEPLOY_VULKAN=0` 已恢复。


