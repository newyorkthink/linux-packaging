# DeepSeek Harness 桌面版写死的路径

## `/usr/lib/deepseek-harness-desktop`

- 为什么写死：AUR 包把程序装在这个目录。`/usr/bin/deepseek-harness-desktop` 是 shell，不是入口。脚本不在构建时再查询安装位置。
- 写死的内容：`/usr/lib/deepseek-harness-desktop`
- 作用：把这个目录里的全部内容放进 `AppDir/bin`。
- 当初报错：没有。这是包装进去的目录，不是扫描失败后补的路径。

## 内置 Python 的库目录

- 为什么写死：这些库不在系统路径上，quick-sharun 不会自己找到。
- 写死的内容：`AppDir/bin/resources/runtime/primary-runtime/dependencies/python/lib`
- 作用：只在第一次 quick-sharun 扫描时加入 `LD_LIBRARY_PATH`。
- 当初报错：仓库记录写的是，2026-10-07 的构建在扫描 `_tkinter` 时找不到 `libtcl9tk9.0.so` 和 `libtcl9.0.so`，构建中止，未生成 AppImage。当时的 Actions 日志已经取不到。

## 官方 extra 的 simdjson

- 为什么写死：构建安装的 nodejs 26.12.1-2 需要 `libsimdjson.so.34`。镜像按软件包名安装的 `simdjson 1:5.0.8-1` 只提供 `libsimdjson.so.35`。
- 写死的内容：`https://archlinux.org/packages/extra/x86_64/simdjson/download/`
- 作用：用官方 extra 当前提供 `libsimdjson.so.34` 的 simdjson 换掉镜像里的那一版，再编译 AUR 包。
- 当初报错全文：

```text
.../esbuild@0.28.2/node_modules/esbuild postinstall: node: error while loading shared libraries: libsimdjson.so.34: cannot open shared object file: No such file or directory
.../node_modules/lefthook postinstall: node: error while loading shared libraries: libsimdjson.so.34: cannot open shared object file: No such file or directory
.../esbuild@0.28.1/node_modules/esbuild postinstall: node: error while loading shared libraries: libsimdjson.so.34: cannot open shared object file: No such file or directory
==> ERROR: A failure occurred in build().
 -> error making: deepseek-harness-desktop-exit status 4
```

当时镜像已经安装 `simdjson 1:5.0.8-1`，构建是 [40829950983](https://github.com/newyorkthink/linux-packaging/actions/runs/40829950983)。

## 当前来源及模板参数

本次核对的 [AUR PKGBUILD](https://github.com/archlinux/aur/blob/deepseek-harness-desktop/PKGBUILD) blob 为 `66add7c7840a196f8ad1f581806e6c247405368e`，[.SRCINFO](https://github.com/archlinux/aur/blob/deepseek-harness-desktop/.SRCINFO) blob 为 `8c7e401bd7663984c1482723025dbb266038ce08`。配方从 DeepSeek 官方 Git tag 构建 Linux 桌面程序，不是从 DEB 提取。这里保存的是取值依据；实际构建继续使用当前 AUR 配方，不锁定本文观察到的版本。

| 固定内容 | 选择依据与作用 | 原始故障记录 |
| --- | --- | --- |
| `deepseek-harness-desktop` 包名 | AUR 包名；用于安装应用和读取同一次安装版本。 | 无新增故障。这是来源参数，不是兼容性补丁。 |
| `AppDir/bin`、`dist` | 标准工作目录；完整程序放入前者，最终 AppImage 和版本文件放入后者。 | 无新增故障，沿用模板。 |
| `APPNAME=deepseek-harness-desktop`、`MAIN_BIN=deepseek-harness` | 沿用已确认的成品应用名；主程序名与 AUR launcher 实际执行的文件一致。 | 无新增故障，不把元数据选择写成运行故障修复。 |
| `STARTUPWMCLASS=deepseek-ai-dsh-desktop` | AUR desktop 写入同一窗口标识，用于窗口与菜单入口匹配。 | 无新增故障，来自包内桌面配置。 |
| `ICON=/usr/share/icons/hicolor/512x512/apps/deepseek-harness.png` | AUR `package()` 从官方 `apps/desktop/resources/icon.png` 安装到此路径。 | 无新增故障，来自包内安装规则。 |
| `DESKTOP=/usr/share/applications/deepseek-ai-dsh-desktop.desktop` | AUR `package()` 生成的桌面入口；直接交给 quick-sharun 使用。 | 无新增故障，来自包内安装规则。 |
| `OUTPATH="$SCRIPT_DIR/dist"`、`OUTNAME=deepseek-harness-desktop.AppImage` | 保持现有构建清单的产物目录和稳定资产名。 | 无新增故障，发布接口不变。 |
| `DEPLOY_GTK=1` | AUR 运行依赖包含 GTK 3，按 Electron 标准部署 GTK 及已安装的输入模块。 | 无新增故障，原有配置保留。 |

## 独立许可证副本

- 为什么保留：上游 [MIT 许可证](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.2-alpha.2/LICENSE) 要求分发软件副本时包含版权及许可声明。AUR 将根许可证单独安装到 `/usr/share/licenses`；目前没有证据证明完整程序目录里的其他资源已完整包含同一声明，不能仅因基础模板没有复制步骤就删除。
- 固定内容：来源 `/usr/share/licenses/deepseek-harness-desktop/LICENSE`，包内目标 `AppDir/share/licenses/deepseek-harness-desktop/LICENSE`。
- 作用：在 AppImage 内保留 `Copyright (c) 2026 DeepSeek` 对应的完整 MIT 许可证文件；保持原有 `install -Dm644` 命令和路径。
- 原始故障记录：没有运行报错。这是许可证分发要求，不是启动兼容性修复；不伪造原始日志。

## 公共版本读取与保存

- 为什么采用：版本来自本次实际安装的 AUR 应用，继续沿用原脚本去掉 epoch 和 pkgrel 的规则；不重复实现公共解析。
- 固定内容：`read_app_version.sh pacman deepseek-harness-desktop`、最终资产 `dist/deepseek-harness-desktop.AppImage` 和版本文件 `dist/version.txt`。
- 作用：第一次 quick-sharun 前取得 `VERSION`，保留 alpha 等渠道标识；最终资产成功且非空后，由单行 `save_appimage_version.sh` 调用写入版本。
- 原始故障记录：没有新增故障。本次为公共入口和模板格式统一，未改变版本来源，也未声称修复新的版本故障。

上述 simdjson、内置 Python 库路径及 `libxcrypt-compat` 的历史故障仍以本文件已有记录和 [README 检查记录](../README.md#检查记录) 为依据；无法取得的旧完整日志仍如实标明，不用摘要冒充原始输出。模板规定的中文 locale 和环境项继续按 [Anylinux 规范](../../anylinux_projects.md#命令行不加中文gui-默认要) 保留。当前实际差异见 [模板差异说明](template-deviations.md)。
