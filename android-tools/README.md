# android-tools AppImage

## 用途与产物

本目录把 Google 官方 Android Platform Tools（`adb`、`fastboot` 等）打包为 `android-tools.AppImage`。

上游软件来源：

- 官方二进制：`https://dl.google.com/android/repository/platform-tools-latest-linux.zip`
- 官方版本说明：<https://developer.android.com/tools/releases/platform-tools>
- 打包基线：[pkgforge-dev/android-tools-AppImage](https://github.com/pkgforge-dev/android-tools-AppImage) 提交 `dfb84638aa053774c9b27a1094e11a950354172c`

正式构建由 `.github/workflows/build.yml` 的 `Build android-tools` Job 完成，固定发布资产为 `android-tools.AppImage`。

## 技术栈

- 上游为 Google 官方 Linux `platform-tools` zip（原生 C/C++ CLI，不是桌面 GUI）。
- 目标架构：当前构建环境的 `uname -m`（与源仓库正式构建一致，x86_64）。
- 打包工具：Arch Linux 容器中的 quick-sharun / sharun，runtime 为 uruntime。
- 多命令入口：仓库内保留 `AppDir/bin/make-symlinks-in-path.hook`，把 `adb`、`fastboot` 等命令链到同一个 AppImage。
- 不启用 quick-sharun 的 `udev-installer.hook`，也不随包安装 udev 规则。该 hook 不是仓库文件，只是构建时由 `ADD_HOOKS` 注入；当前构建不设置该变量。

## 打包方式

沿用源仓库已验证的 AnyLinux / quick-sharun 路线，不改用 linuxdeploy。不套用 Arch `/usr/bin` 最短模板，因为上游是官方 zip，不是发行版软件包。

1. 使用 `get-debloated-pkgs --add-common --prefer-nano ! mesa ! vulkan` 准备精简环境。
2. 随后安装 quick-sharun 最小基础包（含 `unzip`、`patchelf` 等）。必须放在 `get-debloated-pkgs` 之后，否则会被卸掉。
3. 下载 Google 官方 `platform-tools-latest-linux.zip`，解压到仓库内已有 `AppDir/bin`（保留 PATH hook 与图标）。
4. 从 `source.properties` 的 `Pkg.Revision` 动态读取版本，不写死。
5. `quick-sharun ./AppDir/bin/*` 收集依赖。
6. `quick-sharun --make-appimage` 生成 `dist/android-tools.AppImage`。
7. 写入 `dist/version.txt`。

workflow 入口：`android-tools/build_android-tools.sh`，`SOFTWARE_KEY=android-tools`。成功后由当前 Job 立即写入 `latest` Release 的 `software_versions.json`。

源仓库 `make-appimage.sh` 末尾的 `quick-sharun --simple-test` 属于测试代码，未迁入。

## 运行与兼容说明

```bash
./android-tools.AppImage adb version
./android-tools.AppImage adb devices
./android-tools.AppImage fastboot --version
```

也可把同一个 AppImage 分别符号链接为 `adb` 和 `fastboot`，之后直接运行对应命令。

启动不弹 udev 安装框。USB 调试权限由系统现有规则处理；若设备无权限，自行安装发行版提供的 Android udev 规则。需要时再在构建脚本中恢复 `ADD_HOOKS=udev-installer.hook` 即可，不必预先在仓库里存放该 hook。

当前已验证：

- 去掉 udev 后的构建：[run 35241927234](https://github.com/newyorkthink/linux-packaging/actions/runs/35241927234)（`success`）
- 实机：`adb version` 为 `37.0.1`，`adb devices` 可列出已连接的 USB 设备
- 源仓库基线构建：[run 33506406831](https://github.com/pkgforge-dev/android-tools-AppImage/actions/runs/33506406831)（2026-09-01，`success`）

## 迁移核对

源仓库文件共 11 个。允许公开迁移并原样保留 Git blob SHA 的文件 4 个：`LICENSE`、`AppDir/.DirIcon`、`AppDir/android-tools.png`、`AppDir/bin/make-symlinks-in-path.hook`。

被排除 7 个：

| 源文件 | 原因 |
| --- | --- |
| `.github/workflows/appimage.yml` | 按规范接入统一 `build.yml`，不复制独立 workflow |
| `.github/workflows/appimage-nightly.yml` | nightly / DEVEL_RELEASE 独立发布流不迁入；默认不构建 nightly |
| `.github/ISSUE_TEMPLATE/report-bug.md` | Issue 模板不属于本仓库打包逻辑 |
| `LATEST_VERSION` | 硬编码版本，改为从官方 zip 的 `source.properties` 动态读取 |
| `README.md` | 按本仓库要求重写中文应用 README |
| `get-dependencies.sh` | 适配进 `build_android-tools.sh` |
| `make-appimage.sh` | 含 `--simple-test`，禁止迁入测试代码；非测试逻辑已适配 |

横向参考：`htop`、`nvtop`（quick-sharun CLI）、`obs-studio`（`get-debloated-pkgs`）。

## 修复记录

### 2026-09-17：迁入 android-tools AppImage

- 日期：2026-09-17
- 现象：本仓库原先没有 Android Platform Tools AppImage。
- 根因：新应用迁移。
- 修改文件：新增 `android-tools/` 目录；接入 `.github/workflows/build.yml`。
- 具体内容：原样复制图标、PATH hook 与 LICENSE；将源仓库构建逻辑适配为动态版本、固定资产名 `android-tools.AppImage` 和统一版本清单。源仓库冒烟测试未迁入。
- 已知结果：初次构建因缺少基础包失败，见后续记录。

### 2026-09-17：安装 quick-sharun 最小基础包

- 日期：2026-09-17
- 现象：先报 `unzip: command not found`，补 unzip 后报 `Missing dependency 'patchelf'`。
- 根因：`get-debloated-pkgs` 之后容器没有 quick-sharun 所需最小基础包。证据：[run 35239278343](https://github.com/newyorkthink/linux-packaging/actions/runs/35239278343/job/105263258202)、[run 35239870134](https://github.com/newyorkthink/linux-packaging/actions/runs/35239870134/job/105265331210)。
- 修改文件：`build_android-tools.sh`。
- 具体内容：在 `get-debloated-pkgs` 之后安装完整最小基础包，不再单补某一个命令。
- 已知结果：[run 35240408020](https://github.com/newyorkthink/linux-packaging/actions/runs/35240408020) 构建成功。实机 `adb` 可运行，但每次启动弹出 udev 安装框。已被下一条覆盖。

### 2026-09-17：去掉自动 udev 安装

- 日期：2026-09-17
- 现象：每次运行 `adb` / `fastboot` 都弹出 udev 安装框。
- 根因：沿用源仓库 `ADD_HOOKS=udev-installer.hook`。官方 `adb` 本身不带该安装流程；现有 USB 访问也不依赖它。
- 修改文件：`build_android-tools.sh`。
- 具体内容：删除 `ADD_HOOKS`、udev 规则下载，以及对 `udev-installer.hook` 的修改。不在仓库中保留该 hook 文件。
- 已知结果：[run 35241927234](https://github.com/newyorkthink/linux-packaging/actions/runs/35241927234) 构建成功。实机 `adb version` 为 `37.0.1`，`adb devices` 可列出 USB 设备。
