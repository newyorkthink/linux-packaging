# 待解决：quick-sharun 的 Mesa / LLVM 依赖导致 AppImage 构建中断

**状态：待解决。** 本文是后续处理任务，不是已实施的修复方案。当前未针对该问题修改公共打包工具、应用构建脚本或依赖安装顺序。

## 处理目标

解决构建环境中的 Mesa `libgallium` 链接 `libLLVM.so` 时，当前 `quick-sharun` 因强制检查而退出的问题。修复应保留程序确实需要的图形功能，避免无必要地打包大型 LLVM 库，同时不破坏此前已验证的构建行为和 AppImage 运行兼容性。

## 已核实的原因及影响

2026-11-08 18:13 UTC，上游 `pkgforge-dev/Anylinux-AppImages` 在提交 [c667d37d4bb827d51cf7dca7d5a314b13aefae24](https://github.com/pkgforge-dev/Anylinux-AppImages/commit/c667d37d4bb827d51cf7dca7d5a314b13aefae24) 中，将 `quick-sharun` 的 Mesa / LLVM 检查由警告改为致命错误。

以前的检查文本为：

```text
WARNING: Detected the bundled libgallium links to libLLVM.so!
```

更新后变为：

```text
ERROR: Detected the bundled libgallium links to libLLVM.so!
```

上游同时加入 `I_WANT_FAT_APPIMAGE=1` 的放行提示以及退出判断：未启用该变量时，只要已经收集的 `libgallium` 链接 `libLLVM.so`，工具便以非零状态退出，构建不能继续进入正常封装流程。

在本仓库中，以下两次运行使用相同源码提交 `0fdeea54494a5a348a4d38c1bf41d9f10adbb07c`：

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [42499042831](https://github.com/newyorkthink/linux-packaging/actions/runs/42499042831) | 85 个 Job 全部成功 | 2026-11-08 16:16 UTC 开始，当时 `quick-sharun` 遇到该依赖仍只打印警告 |
| [42542271492](https://github.com/newyorkthink/linux-packaging/actions/runs/42542271492) | 85 个 Job 中 48 个失败、37 个成功 | 2026-11-09 00:49 UTC 开始，48 个失败 Job 均在 `quick-sharun` 阶段出现上述致命错误 |

失败运行中存在 Arch 镜像源下载缓慢及重试记录，但受影响的 48 个 Job 最终失败原因一致，**不是 `yay` 下载重试耗尽**。两次运行的仓库源码相同，差异来自构建时获取的上游打包工具。不能把这些失败分别归因于 48 个应用脚本。

这项变化也使 [原有 Mesa / LLVM 历史说明](../known-risks/quick-sharun-mesa-llvm-explanation.md) 中的警告可继续构建结论仅适用于当时的上游版本，不能直接套用于当前工具。

## 后续处理范围

1. **重新核实上游现状。** 开始修改前读取当前 `quick-sharun` 的检查代码，确认上游是否已经调整规则，并核对构建 Action 实际获取工具的方式。上述提交和两次运行记录是历史证据，不能代替届时的最新状态。
2. **梳理依赖来源。** 对照实际受影响 Job 的构建脚本、公共安装入口、容器依赖以及 `quick-sharun` 扫描参数，确认 `libgallium`、`libLLVM.so` 是如何进入 AppDir 的。应区分 OpenGL / EGL / GBM / Vulkan 的真实需求，不能因为部分程序需要图形界面就一律部署相同的驱动。
3. **评估上游精简 Mesa。** 优先研究 [archlinux-pkgs-debloated](https://github.com/pkgforge-dev/archlinux-pkgs-debloated) 的 `mesa-mini` 和 [get-debloated-pkgs](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/get-debloated-pkgs.sh) 的适用性。`mesa-mini` 通过移除 Mesa 对 LLVM 的链接减轻依赖；`mesa-nano` 额外使用 `-Os`，上游提示可能影响性能和稳定性，不应只为减小体积而默认使用。
4. **核对安装和收集顺序。** 如果采用精简软件包，必须结合现有依赖安装阶段确定执行位置，避免后续 `pacman` / `yay` 安装重新替换精简包。先确认是否有可复用的公共处理位置，再评估是否存在需要保留的应用特例；不得未经核对就批量改动应用脚本和标准模板。
5. **保留必要运行库。** 不能直接删除所有 Mesa 或 LLVM 文件，也不能仅在 `quick-sharun` 完成后删库以试图绕过前置检查。LLVM 可能被 Mesa 以外的组件使用；必要的图形驱动、库及间接依赖应按实际 ELF 依赖与运行功能判定。
6. **区分临时放行和长期修复。** 上游提供 `I_WANT_FAT_APPIMAGE=1` 用于允许保留大型 Mesa / LLVM 依赖，但这不会消除体积及兼容性风险，不得未经单独评估就设为所有应用的永久默认值。

## 验收与完成条件

- 受该检查影响的构建任务能够完成必要的依赖收集和 AppImage 封装，且没有引入新的依赖缺失、启动失败或已确认功能退化。
- 对照此前正常工作的应用检查回归影响，不能只以 `quick-sharun` 不再报错作为验收依据。
- 核实最终产物中 Mesa、LLVM 及相关动态库的实际依赖关系；如果采用精简 Mesa，应确认确实解决依赖链问题，而不是单纯隐藏日志。
- 对修改范围、构建结果和实际验证结论给出对应证据；没有验证过的运行兼容性不得写成已通过。
- 事项完成并通过相应验收后，**必须从 `docs/pending/` 删除本待办文件，并删除该目录索引中的任务条目**。原有历史技术记录和提交记录保留，不再让已解决的事项占据待办清单。

## 相关来源

- [上游改变检查规则的提交](https://github.com/pkgforge-dev/Anylinux-AppImages/commit/c667d37d4bb827d51cf7dca7d5a314b13aefae24)
- [上游 quick-sharun 工具](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh)
- [上游精简软件包](https://github.com/pkgforge-dev/archlinux-pkgs-debloated)
- [上游精简软件包处理工具](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/get-debloated-pkgs.sh)
- [本仓库既有 Mesa / LLVM 历史记录](../known-risks/quick-sharun-mesa-llvm-explanation.md)
- [本仓库 quick-sharun 通用机制记录](../packaging-cases/quick-sharun.md)
