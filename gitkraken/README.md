# GitKraken AppImage

## 用途与产物

本目录将 GitKraken Desktop 官方 Linux 稳定版重新封装为 AppImage，稳定产物名为：

```text
gitkraken.AppImage
```

GitKraken Desktop 是基于 Electron / Chromium 的图形化 Git 客户端。本项目只处理 Linux AppImage 封装、运行依赖和中文 UTF-8 / 输入法兼容，不修改 GitKraken 的授权机制、账户状态、订阅限制或应用功能。

上游来源：

- 官方网站：`https://www.gitkraken.com/`
- 官方 production release 元数据：`https://api.gitkraken.dev/releases/production/linux/x64/RELEASES`
- 官方 Linux x64 tar.gz：根据上述元数据动态解析当前稳定版后，从 GitKraken 官方 production API 下载。
- AUR `gitkraken`：仅用于核对官方 tar.gz 的目录布局、运行依赖、desktop 语义和 `chrome-sandbox` 权限，不作为二进制来源。

## 技术栈

GitKraken Desktop Linux 版采用 Electron / Chromium 技术栈。官方 Linux tar.gz 包含 GitKraken 主程序、Electron / Chromium 组件、`resources`、官方 launcher、`chrome-sandbox` 和应用图标。

GitKraken 自身还包含多个 Node.js 原生扩展（`*.node`），例如仓库扫描、NodeGit、PTY、文件监听等模块。这些文件本质上是由 Electron / Node.js 通过 `dlopen()` 加载的共享对象，不能按普通可执行程序替换为 sharun wrapper。

当前 AppImage 目标架构为 `x86_64`。AUR 当前主要运行依赖为 GTK3、NSS、libsecret 和 libxkbfile；本项目在此基础上补齐 Electron / Chromium 常见运行库、GTK3 输入法模块以及 AppImage 内可独立使用的 `zh_CN.UTF-8` glibc locale 数据。

## 打包方式

`build_gitkraken.sh` 采用官方 tar.gz + quick-sharun 的方式，不重新编译 GitKraken：

1. 读取 GitKraken 官方 production `RELEASES` 元数据中的当前稳定版版本号，不在仓库中锁定应用版本。
2. 校验版本格式和官方下载地址后，下载对应版本的 `gitkraken-amd64.tar.gz`，并记录实际下载文件的 SHA-256。
3. 检查归档路径安全性，要求全部文件位于官方 `gitkraken/` 顶层目录下。
4. 原样保留官方应用目录内容，仅将其放入 AppImage 的应用目录；不修改 GitKraken 的 JS / Electron 资源和授权逻辑。
5. 保留上游 `chrome-sandbox` 的 `4755` 文件模式。正式启动不会强制添加 `--no-sandbox`；只有 GitHub Actions 的 root 图形冒烟测试临时使用该参数。
6. 扫描官方应用目录中的全部 ELF；普通 ELF 交给 quick-sharun 收集运行依赖，`*.node` Node 原生模块保留官方文件本体，不作为 quick-sharun executable 输入，只把这些模块解析到的外部动态库依赖交给 quick-sharun。
7. quick-sharun 完成后逐个对比官方 `*.node` 的 SHA-256 与文件模式，防止原生模块被 sharun wrapper、strip、patchelf 或其他后处理改写。
8. 带入 GTK3 的 IBus 与 Fcitx5 input method module 和对应 `immodules.cache`。
9. 使用 `localedef --no-archive` 生成 `zh_CN.UTF-8` glibc locale，并放入 quick-sharun / AnyLinux 使用的 AppImage locale 目录，避免仅设置 `LANG` 但 AppImage 内没有对应 locale 数据。
10. 根据上游 desktop 语义生成 AppImage desktop 入口并使用官方图标，最终输出 `dist/gitkraken.AppImage`。

## 中文环境与输入法

AppImage 启动 wrapper 设置以下中文 UTF-8 locale：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
```

同时 AppImage 构建中加入：

```text
/usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so
/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
```

并在 AppImage 内生成：

```text
shared/lib/locale/zh_CN.utf8
```

quick-sharun 本身会为 AnyLinux runtime 准备 `C.UTF-8` / `en_US.UTF-8` fallback；本项目另外显式生成 `zh_CN.UTF-8`，使 wrapper 设置的中文 locale 在宿主没有对应 glibc locale 时仍可由 AppImage 内部数据解析。

wrapper 不强制覆盖宿主已经配置的 `GTK_IM_MODULE`，因此宿主正在使用 Fcitx5 或 IBus 时仍按现有输入法会话工作。正常输入中文仍要求宿主已经启动并配置相应中文输入法；中文字符字形显示也取决于宿主可用的 CJK 字体。

这里的“中文环境”是中文 UTF-8 locale、中文字符处理和 GTK 输入法兼容，不是非官方界面翻译。GitKraken Desktop 当前没有官方中文 UI 语言包，因此本项目不会修改 Electron / JS 资源去注入第三方中文界面；应用界面语言仍由 GitKraken 官方版本本身决定。

## 构建

正式构建由仓库统一 `.github/workflows/build.yml` 执行，GitKraken 对应脚本为：

```text
gitkraken/build_gitkraken.sh
```

构建输出：

```text
dist/gitkraken.AppImage
dist/gitkraken.AppImage.sha256
dist/version.txt
dist/source.sha256
```

## 运行

在 AppImage 所在目录执行：

```bash
./gitkraken.AppImage
```

如需中文输入，宿主的 Fcitx5 或 IBus 需要已经正常运行并完成中文输入法配置。

## 验证

构建脚本会执行以下检查：

- 官方 production release 元数据能够解析出严格的稳定版版本号，且下载地址必须属于预期 GitKraken production x64 路径。
- 官方 tar.gz 可正常读取，全部归档内容位于 `gitkraken/` 顶层目录且不存在绝对路径或 `..` 路径穿越。
- 官方包包含 x86_64 GitKraken 主程序、launcher、PNG 图标和 `chrome-sandbox`。
- 打包前扫描官方应用目录全部 ELF，逐项检查 `ldd` 不存在 `not found`。
- 将 `*.node` 与普通 executable ELF 分开处理，并在 quick-sharun 部署后逐个核对官方原生模块的 SHA-256 和文件模式没有变化。
- desktop 文件通过 `desktop-file-validate`。
- quick-sharun 部署后按最终 GTK3 路径核对 IBus / Fcitx5 module、有效 ELF 目标和 `immodules.cache` 注册项；允许 quick-sharun 按共享库语义使用指向有效 ELF 的符号链接。
- 最终 AppImage 能重新提取，并确认 GitKraken 主程序、官方 launcher、图标、desktop、`chrome-sandbox`、`zh_CN.UTF-8` / `zh_CN:zh` 设置、真实 `zh_CN.utf8` locale 数据以及 IBus / Fcitx5 GTK3 输入模块存在。
- 最终提取后再次逐个比对所有官方 `*.node` 的 SHA-256 和文件模式，确保 DwarFS/AppImage 封装没有改写 Node 原生模块。
- 使用最终提取出的 `shared/lib/locale` 通过 `locale charmap` 验证 `zh_CN.UTF-8` 实际解析为 `UTF-8`，而不是只检查环境变量文本。
- 最终主程序再次检查动态库依赖。
- 使用隔离 HOME / XDG 目录和 Xvfb 启动最终 AppImage；除了要求进程正常运行，还必须通过 `xwininfo` 检测到实际 GitKraken X11 顶层窗口。
- GUI 验证日志显式拦截 Node 原生模块 `dlopen()` 失败、`cannot dynamically load position-independent executable` / `无法动态加载位置无关可执行文件`、共享库加载失败、ELF 格式错误和崩溃等致命错误，不能再仅以 `timeout` 返回码判断成功。
- 生成最终 AppImage SHA-256 供审计。

## 变更记录

### 2026-09-02：首次加入 GitKraken AppImage 与中文环境

- 新增 `gitkraken/build_gitkraken.sh` 和本 README。
- 以 GitKraken 官方 production release 为唯一应用二进制来源，版本动态获取，不锁定当前版本。
- 参照 AUR `gitkraken` 核对官方 tar.gz 布局、GTK3 / NSS / libsecret / libxkbfile 依赖和 `chrome-sandbox` 权限。
- 加入 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`，并带入 GTK3 的 Fcitx5 / IBus 输入模块；不覆盖宿主输入法选择。
- 明确不注入第三方中文 UI，不修改 GitKraken 授权或订阅逻辑。
- 接入仓库统一 `build.yml`，并增加归档安全、ELF / `ldd`、desktop、最终 AppImage 提取和隔离 Xvfb 冒烟检查。

### 2026-09-02：修复构建环境缺少 hostname

- 故障现象：GitHub Actions 在进入 GitKraken 构建脚本后报 `构建环境缺少命令：hostname`，尚未进入正式 AppImage 封装。
- 根因：脚本需要把 `/usr/bin/hostname` 一并交给 quick-sharun，但 Arch Linux 构建容器中该命令由 `inetutils` 提供，原依赖列表没有安装该包。
- 修改文件：`gitkraken/build_gitkraken.sh`。
- 修复内容：仅在构建依赖中增加 `inetutils`，不改变 GitKraken 下载、中文环境、输入法、sandbox 或打包逻辑。
- 对应提交：`d9a1627dd9c3f5547fecab7aa6216d9e2dd73435`。
- 验证结果：后续 Actions 已通过原 `hostname` 故障点并完成约 269.7 MiB AppImage 的 DwarFS 封装，随后暴露出更靠后的 GTK 输入模块最终校验问题。

### 2026-09-02：修正 GTK 输入模块最终校验并补齐真实 zh_CN locale

- 故障现象：AppImage 已成功完成 DwarFS 封装，但最终提取验证报 `最终 AppImage 缺少 IBus GTK3 输入模块`。
- 根因：Actions 日志已确认 quick-sharun 在打包输入阶段把 `im-ibus.so` 与 `im-fcitx5.so` 部署到 GTK3 immodules 目录；原验证却使用 `find -type f`，只接受普通文件，与 quick-sharun 对共享库原名可保留为指向有效 ELF 的符号链接这一部署语义不一致。
- 同步核实：quick-sharun 对 glibc 默认只保证 `C.UTF-8` 与 `en_US.UTF-8` fallback；此前虽然设置了 `LANG=zh_CN.UTF-8`，但没有显式生成 AppImage 内的 `zh_CN` glibc locale 数据。
- 修改文件：`gitkraken/build_gitkraken.sh`、`gitkraken/README.md`。
- 修复内容：按确定的 GTK3 最终路径使用 `-e` 与 `readelf` 验证 IBus / Fcitx5 module，同时验证 `immodules.cache` 注册项；使用 `localedef --no-archive` 生成 `zh_CN.utf8` 并加入 AnyLinux locale 目录；最终提取后再验证 locale 数据并用 `locale charmap` 确认实际为 `UTF-8`。
- 验证结果：以对应 GitHub Actions 最终运行结果为准；本记录不把尚未完成的 CI 描述为已成功。

### 2026-09-02：修复 GitKraken Node 原生模块被 quick-sharun wrapper 替换

- 故障现象：Actions 构建显示成功，但实际运行 `gitkraken.AppImage` 没有任何 GUI；终端报 `find-git-repositories/build/Release/findGitRepos.node: 无法动态加载位置无关可执行文件`，随后出现 `UnhandledPromiseRejectionWarning`。
- 根因：Run `33616739549` 的完整构建日志已经显示 quick-sharun 把 `findGitRepos.node`、`nodegit.node`、`pty.node`、`nsfw.node` 等 `*.node` 文件识别为 nested executable，并执行 `Wrapped nested bin executable ... with sharun`。Node/Electron 需要通过 `dlopen()` 加载这些原生模块，文件被替换为 sharun executable wrapper 后就会触发该错误。
- 原验证缺陷：同一个 Run 的 Xvfb 日志其实已经出现完全相同的 `findGitRepos.node` 错误，但旧验证只接受进程存活到 25 秒并允许 `timeout` 返回 `124`，致命错误正则也没有覆盖 Node 原生模块 `dlopen()` 失败，因此产生了错误的绿色 CI。
- 修复内容：`*.node` 不再作为 quick-sharun executable 输入；仍对其执行 `ldd`，并把解析到的 AppDir 外部动态库依赖交给 quick-sharun；quick-sharun 前后和最终 AppImage 提取后均逐个比对官方 `*.node` 的 SHA-256 与文件模式。
- GUI 验证增强：新增 `xorg-xwininfo`，Xvfb 测试必须实际检测到 GitKraken X11 顶层窗口；同时显式拦截 `UnhandledPromiseRejectionWarning` 的 `.node` 错误和中英文 `cannot dynamically load position-independent executable` 报错。
- `libva` / VA-API 初始化警告不是此次无界面的根因，因此没有用 `--no-sandbox`、禁用 VA-API 或其他无关参数去掩盖该问题。
