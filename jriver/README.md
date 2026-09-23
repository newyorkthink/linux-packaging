# JRiver Media Center AppImage

本目录构建 x86_64 JRiver Media Center。上游应用来自当前 AUR `jriver-media-center` 配方指向的官方 Linux DEB；主程序是原生 C/C++ 与 GTK3，另有 JRWeb/CEF、WebKitGTK 和音频运行库。正式构建由 [Build AppImages](../.github/workflows/build.yml) 的独立 `Build JRiver` Job 执行，产物位于 `jriver/dist/`，Release 名称随实际主程序为 `mediacenterN.AppImage`。

## 当前入口与修复记录

| 文件 | 用途 |
| --- | --- |
| `build_jriver_anylinux_sharun.sh` | 当前 CI 入口；AnyLinux 环境中的 quick-sharun、私有 CEF/音频兼容层、pathmap 和 appimagetool |
| [REPAIR_HISTORY_ANYLINUX_SHARUN.md](./REPAIR_HISTORY_ANYLINUX_SHARUN.md) | 旧路线的完整修复、失败尝试和实机记录 |
| `build_jriver_anylinux_runimage.sh` | 保留的 RunImage + quick-sharun 构建入口；当前 CI 不调用 |
| [REPAIR_HISTORY_ANYLINUX_RUNIMAGE.md](./REPAIR_HISTORY_ANYLINUX_RUNIMAGE.md) | RunImage 路线的完整构建、运行和 Rofi 问题记录 |
| `jriver_cef_runtime.sh` | 历史 CEF 辅助脚本；两个入口均未调用 |

**2026-09-23：** 历史旧入口实际使用 AnyLinux + quick-sharun + appimagetool，仓库的 JRiver 脚本与提交历史均没有 linuxdeploy 调用。因此按真实工具命名并切回旧入口；没有把旧 Sharun 脚本伪装为 linuxdeploy，也没有套用普通 linuxdeploy 流程。旧入口的 quick-sharun preload 目录兼容、CEF ABI 检查、网页音频闭包、Fcitx5 和 glibc/pathmap 隔离保持原实现；此次只补充实际资产名传递。

旧路线最后一次已记录的实机结果为 **2026-09-12 GUI 可显示，影院模式鼠标点击卡住**。切回后的新构建、GUI、网页音频、文件选择器、Fcitx5 实际输入和影院模式均**尚未重新验证**。RunImage 路线 2026-09-18 曾确认终端 GUI、简体中文和文件选择器，但通过 Rofi run 无窗口；其完整证据与禁止重复的尝试保留在独立记录中，不能移作旧路线的验证结果。

## 运行

在 Linux 终端进入下载的 AppImage 所在目录后执行：

```bash
# 给当前下载的 JRiver AppImage 添加执行权限
chmod +x ./mediacenter36.AppImage

# 启动 JRiver Media Center
./mediacenter36.AppImage
```

主版本变化时应使用 Release 中实际的 `mediacenterN.AppImage` 文件名。构建和发布在 GitHub Actions 的临时环境执行，无需在本机安装打包工具。

## 2026-09-23：切换正式入口

- 原因：用户要求保留 RunImage 脚本并切回此前记录过 CEF、网页音频和隔离修复的旧路线。历史核查发现旧路线为 quick-sharun，没有 linuxdeploy 版本。
- 修改范围：两个脚本和两份修复记录按真实路线重命名；更新 `.github/appimage-apps.json`、`.github/workflows/build.yml` 的 JRiver 唯一选择项与独立 Job 入口；旧入口生成 `release-name.txt`，避免主版本变更后发布名仍沿用 36。独立 `runimage/jriver-media-center/`、Rofi 和其他应用不变。
- 检查：核对历史脚本、CEF/音频补丁的来源和构建链，进行 Shell、JSON、workflow 及选择逻辑静态检查；未对本次构建产物或实机功能作成功判定。
