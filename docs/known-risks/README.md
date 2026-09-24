# 已知隐患

这个目录只记已经看过、暂时不改代码的打包问题和隐患。

这里有记录，不表示要去改对应构建脚本。真要改某个应用时，单独处理那个应用。

| 事项 | 决定 | 说明 |
| --- | --- | --- |
| quick-sharun 的 Mesa / LLVM 红字 | 保留 | 原文未改，见 [quick-sharun-mesa-llvm-explanation.md](./quick-sharun-mesa-llvm-explanation.md) |

红字是 `WARNING: Detected the bundled libgallium links to libLLVM.so!`。quick-sharun 收进 `libgallium` → `libLLVM` 时自己打印。没有开关。库留着，这行就在。它不是构建失败，带上这些库也能启动。代价是包变大，而且这是构建机的 Mesa 驱动，换显卡或旧内核可能不兼容。

## Discord 代码核对

2026-09-24 核对 `discord/build_discord.sh`：

- 已经没有删除 `libgallium*`、`libLLVM*`、`libGLX_mesa*` 的 `find -delete`。
- 已经没有删库之后的 `sharun -g`。
- `DEPLOY_OPENGL=0` 和 `DEPLOY_VULKAN=0` 还在。这两个开关挡不住动态扫描把上述库收进去。
- `bash -n` 通过。

这次核对没有改 Discord 脚本。
