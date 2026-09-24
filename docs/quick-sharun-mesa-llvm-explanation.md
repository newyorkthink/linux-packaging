# quick-sharun 的 Mesa / LLVM 红字：v2rayN、Discord 与 mpv

核对日期：2026-09-24。本文只解释这三次指定构建和当时下载、分别解包核对的 `latest` AppImage。之后重新发布的产物应重新检查，不能把本文的文件清单当成所有版本的固定结论。

## 一句话结论

**三个程序都可能使用图形界面；是否出现这条红字，取决于打包时 quick-sharun 实际收进了哪些构建机图形库，和“是不是 GUI 软件”“有没有播放文件”不是一回事。**

| 程序 | 打包时的观察 | 本次核对的最终 AppImage | 怎么理解 |
| --- | --- | --- | --- |
| v2rayN | quick-sharun 收进 `libGLX_mesa.so.0`、`libgallium-26.2.3-arch1.1.so`、`libLLVM.so.22.1`，打印 LLVM 红字 | 三项都在 | 红字描述了这个成品里实际存在的一条库依赖链；构建成功，不能说成“包里没有 LLVM” |
| Discord | quick-sharun 同样先收进三项，打印 LLVM 红字 | 三项都不在；仍有 `libgbm.so.1.0.0`、`gbm/dri_gbm.so` | 现行脚本在扫描之后、封装之前删掉指定的三类库并重建 sharun 的库路径清单；**删除动作发生在红字之后**。因此日志保留早先的红字，成品却没有那三项。不能说“Discord 没有任何 Mesa 组件” |
| mpv | 该次日志没有收进上述三项，也没有 LLVM 红字；有另外的 glycin、libjack 提示 | 本次只核对了构建日志及脚本，没有据此宣称 mpv 的每个成品文件都经过解包检查 | mpv 是可以打开图形窗口的播放器；这次 quick-sharun 收集依赖时没有走到上述 GLX Mesa → LLVM 路径 |

## 红字原文是什么意思

两次日志里的关键提示是：

> WARNING: Detected the bundled libgallium links to libLLVM.so!

工具随后说明这会把较大的 LLVM 库带入应用、可能占用额外空间，并提醒不要随意捆绑发行版图形驱动。**这是 quick-sharun 的打包提示，不是 shell 报错，也不是这两次构建失败的结论。**判断构建是否完成要看 Job 的结果；判断文件最终在不在，要检查完成封装的 AppImage。红色字体本身不能回答这两个问题。

Discord 那次还有：

> WARNING: GNOME glycin has been deployed!

这表示工具部署了 GNOME glycin。日志中红色的 `* added glycin-fix.so for gnome glycin` 也是部署信息。mpv 那次也有 glycin 和 libjack 的提示；**它们不是 Mesa / LLVM 警告**，不能因为同为红色就当成同一种故障。

## 为什么 mpv 与另外两个不同

仓库当前脚本的收集入口不同：

1. `mpv/build_mpv.sh` 先执行 `quick-sharun /usr/bin/mpv`。等依赖收集完成后，脚本才添加 `mpv-launch-gui.src.hook`：用户双击最终 AppImage、没有传参数时，hook 才把参数改成 `--player-operation-mode=pseudo-gui`。所以最终成品可以走图形界面，不代表之前的依赖收集已经按该启动模式走过。
2. `discord/build_discord.sh` 把 Discord 的图形主程序、自带 Electron/Chromium 库和若干系统模块交给 quick-sharun；`v2rayn/build_v2rayn.sh` 把 v2rayN 主程序放在输入首位，并收集其他符合条件的 ELF。它们的日志都明确显示 quick-sharun 在本次运行中复制了这三项构建机库。
3. 本次证据能证明**收集结果不同**、mpv 的伪 GUI hook 添加顺序不同；不能仅凭这些日志断言其他构建环境里触发 GLX 加载的唯一内部原因。不要用“mpv 没播放文件”解释差别：其他两个程序也没有播放文件，而 mpv 仍然是 GUI 程序。

**安装了 Mesa 不等于 AppImage 一定包含 Mesa 驱动。**打包环境安装的软件包是可供收集的候选；要看 quick-sharun 的扫描和最终封装。也不要因为设置了 `DEPLOY_OPENGL=0` 就断言动态扫描绝不会碰到 Mesa：Discord 当前脚本设置了 `DEPLOY_OPENGL=0 DEPLOY_VULKAN=0`，对应日志仍显示扫描阶段复制了这些库。

## v2rayN 与 Discord 的成品证据

本次分别下载 `latest` 的 v2rayN、Discord AppImage，并分别解包，避免两个同名 `squashfs-root` 混在一起。对最终成品的库目录核对结果：

| 产物 | `libGLX_mesa.so*` | `libgallium*.so*` | `libLLVM.so*` | 其他相关文件 |
| --- | --- | --- | --- | --- |
| `v2rayn.AppImage` | 有 | 有 | 有 | `readelf -d` 显示 `libGLX_mesa.so.0.0.0` 需要 `libgallium-26.2.3-arch1.1.so`，后者需要 `libLLVM.so.22.1` |
| `discord.AppImage` | 无 | 无 | 无 | 有 Mesa 的 `libgbm.so.1.0.0` 与 `gbm/dri_gbm.so` |

库名和尺寸会随 Arch 系统包升级变化。本次 v2rayN 的 `libgallium` 约 55 MB、`libLLVM` 约 171 MB，说明这条警告确实对应实际打进包内的大库。文件是否应删除，不能只看尺寸或红字；删除会改变最终产物的库集合，应当单独评估具体应用。

Discord 的当前脚本在 quick-sharun 之后执行 `find "$APPDIR/lib" ... -delete`，目标仅是 `libgallium*.so*`、`libLLVM.so*`、`libGLX_mesa.so*`，随后执行 `"$APPDIR/sharun" -g` 重建库路径清单。若把这段删掉，不能继续声称 Discord 成品没有那三项；本次扫描日志显示它们在删除前已经进了 AppDir。

## 实际维护时怎么判断

看到 `WARNING: Detected the bundled libgallium links to libLLVM.so!` 时，先把它理解成**打包工具指出了一个需要核对的体积和兼容性问题**，不要直接当作构建错误；也不要仅凭 Job 成功就说“最终没有 LLVM”。

- 要回答“这次是否构建完成”：看该次 Job 的最终状态和产物生成步骤。
- 要回答“最终包里有没有”：解包**本次发布的** AppImage，检查 `libGLX_mesa*`、`libgallium*`、`libLLVM*`，必要时用 `readelf -d` 查实际依赖。
- 要回答“为什么某应用有、另一个没有”：比较本次传给 quick-sharun 的入口与参数、它的实际复制日志，以及扫描后到封装前的脚本操作；不能仅按应用是否 GUI 或构建机是否安装 Mesa 推断。
- 要决定是否改打包行为：依据该应用的成品内容和运行需求单独处理。当前核查**不要求**改 mpv、v2rayN 或 Discord 的脚本，也不构成对所有机器图形驱动兼容性的证明。

## 对应记录

- [v2rayN 构建 Job 107504379097](https://github.com/newyorkthink/linux-packaging/actions/runs/35957730418/job/107504379097)：复制 Mesa/LLVM 三项并打印警告，Job 成功。
- [Discord 构建 Job 107510358634](https://github.com/newyorkthink/linux-packaging/actions/runs/35961327032/job/107510358634)：复制三项并打印警告；脚本随后删除指定三项，Job 成功。
- [mpv 构建 Job 107508606529](https://github.com/newyorkthink/linux-packaging/actions/runs/35960745514/job/107508606529)：该次没有 Mesa/LLVM 三项的复制记录或对应警告，Job 成功。
- [mpv 构建脚本](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh)、[Discord 构建脚本](https://github.com/newyorkthink/linux-packaging/blob/main/discord/build_discord.sh)、[v2rayN 构建脚本](https://github.com/newyorkthink/linux-packaging/blob/main/v2rayn/build_v2rayn.sh)。

## 2026-09-24：Discord 不再删除这三项

上文描述的是当时的脚本。用户要求去掉 Discord 在 quick-sharun 之后删除 `libgallium*`、`libLLVM*`、`libGLX_mesa*` 的代码。红色警告来自 quick-sharun 本身，发生在删除之前，没有开关可以在库仍被收进包内时关掉它。过滤日志不能当成“没有警告”。

当前选择是默认保留这行红色警告，成品也保留扫描收进的这三项。不能再按上文声称 Discord 成品没有它们。新成品仍需解包核对。

