# Gufw AppImage

## 用途与产物

本目录在 Ubuntu 24.04 构建 Gufw AppImage，产物为 `dist/gufw.AppImage`。Python、PyGObject、GTK 和 GLib 等原生运行库只使用当前 Ubuntu 24.04 构建环境的软件包，采用 glibc 2.39 的构建基线。Gufw 界面从 Ubuntu 官方 `resolute / universe` 签名索引动态选择 `Architecture: all` 的当前包，仅解包应用文件，不把该软件源加入系统，也不安装该发行版的原生库。版本不写死；防火墙规则仍由宿主机的 `/usr/sbin/ufw` 执行。

## 技术栈与打包方式

Gufw 26.04 是 GTK3、Python 3 和 PyGObject 程序，并且必须以 root 运行。脚本以 [GTK Ubuntu 仓库模板](../Templates/appimage/linuxdeploy-gtk-apt.sh) 为底稿，但标准生成器覆盖不了 Python 运行包、宿主命令隔离和 root 启动，因此采用已验证的专用流程。例外范围见 [模板差异](./docs/template-deviations.md)。固定路径见 [固定配置](./docs/hardcoded.md)。

公共 APT 入口只安装构建环境的依赖，再按名称解包解释器、标准库、PyGObject、GI typelib 和 GTK3。Gufw 的 DEB 由公共签名 APT 下载入口取得：使用官方归档公钥验证 `InRelease`，从 `amd64` 索引精确选择包架构 `all`，核对索引和 DEB 的 SHA-256、大小及包身份，再通过公共归档入口解包。公共解包入口不会递归解依赖，缺少的包由构建脚本显式列出。解释器动态链接共享 `libpython` 时，再追加该库所属的软件包；静态链接时不追加，也不因此中止构建。linuxdeploy 使用 GTK 插件；解释器、`_gi.so` 和 `libgtk-3.so.0` 用 `--deploy-deps-only` 收集已经在 AppDir 里的文件的依赖，不使用 `--executable`。第二次部署显式指定 `usr/share/applications/gufw.desktop`，由该入口选择 Gufw 图标。

完整启动脚本在第二次 linuxdeploy 之前写入根 `AppRun`。官方插件若实际生成 hook，由 linuxdeploy 自行保留 `AppRun` → `AppRun.wrapped`。脚本不创建、不删除、也不要求 hook 存在。

直接运行 AppImage，启动脚本优先使用 pkexec 图形授权，取消认证时退出。图形授权不可用且有终端时回退 sudo。Gufw 以 root 运行。普通用户启动时，脚本先将 AppDir 复制到 `/tmp` 的普通目录，再启动副本中的 Python，程序退出后删除副本。整个 AppImage 已由 root 挂载时直接使用该挂载。

启动脚本保留官方 GTK3 插件生成的路径，将 `GTK_EXE_PREFIX`、`GTK_PATH` 和 `GTK_IM_MODULE_FILE` 映射到临时副本，再传给 root。插件未提供有效路径时，脚本按副本中的实际目录补齐。输入法缓存使用副本中实际存在的 `immodules.cache`，未找到时不设置 `GTK_IM_MODULE_FILE`。主界面使用包内 `Adwaita:dark` 深色主题。先准备对应目录的 `LOCPATH`，再通过 `/usr/bin/env` 将 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_ALL=zh_CN.UTF-8` 一同传给界面子进程，避免继承的 locale 覆盖中文配置。启动 Shell 保留宿主 locale，不提前切换到包内中文 locale。

root 界面处于 X11，且宿主已通过 `XMODIFIERS=@im=fcitx` 或 `@im=ibus` 配置 XIM 时，使用 `GTK_IM_MODULE=xim` 连接宿主输入法；其他会话保留宿主 GTK 输入模块。Fcitx／IBus GTK 模块和 XIM 模块仍随包保留。原生 Wayland 不强制使用 XIM。授权对话框由宿主 Polkit agent 显示，其语言和主题由宿主会话决定。

主窗口、首选项和关于窗口的图标改用 GTK 图标名 `gufw`，从已有包内 `hicolor` 资源查找，避免访问宿主绝对图标路径。普通规则与日志文本继承 GTK 主题前景色，避免深色下固定黑色文字难以辨认；红、绿等状态色保持原样。

宿主命令的环境清理是解包副本里 `gufw/model/ufw_backend.py` 的补丁，不是启动脚本里的包装程序。`_run_cmd` 改为调用 `_host_command_env`：删除规则、启停、改策略和改日志级别不再继承 `PYTHONHOME`、`PYTHONPATH` 和 `LD_LIBRARY_PATH`。同一函数里的 `grep`、`cat`、`ls` 和 `hostname` 也使用这份清理后的环境。

## 运行

Debian 系发行版可在终端执行以下依赖安装命令，需预先安装 aptitude。

```bash
# 安装 UFW、pkexec 和 Polkit 授权服务
sudo aptitude install ufw pkexec polkitd
```

在本应用目录中运行 AppImage。

```bash
./dist/gufw.AppImage
```

需要宿主机已经安装可执行的 `/usr/sbin/ufw` 和 Polkit。没有 pkexec 时，只能在终端里用 sudo 授权。`/tmp` 必须允许执行程序。不要在没有图形环境变量时用 sudo 启动整个 AppImage。若整个 AppImage 已经由 root 挂载，则直接使用该挂载，不再复制。

## 首次启动与配置保存位置

本 AppImage 先检查宿主机是否有可执行的 `/usr/sbin/ufw`。没有时会提示并退出，尚未启动 Gufw 的 Python 入口，因此不会初始化宿主 `/etc/gufw/`。安装 UFW 本身与 Gufw 的配置初始化是两个步骤。启动检查见 [AppRun](./AppRun#L208-L211)。

通过启动检查并完成授权后，Gufw 读取宿主配置。当 `/etc/gufw/` 中一个 `*.profile` 都没有时，会自动创建家庭、办公室、公共三套方案，并记录当前配置。已有配置时读取、更新原文件，退出 AppImage 不会清理这些持久配置。

Gufw 自己的主要配置放在系统目录，因此通常不会在用户的 `~/.config/` 中找到对应配置：

| 位置 | 用途 |
| --- | --- |
| `/etc/gufw/gufw.cfg` | 当前选中的方案、窗口与界面偏好 |
| `/etc/gufw/*.profile` | 各方案的状态、默认策略及 Gufw 保存的规则编辑信息 |
| `/var/log/gufw.log` | Gufw 界面的操作日志 |
| `/etc/ufw/user.rules`、`/etc/ufw/user6.rules` | UFW 的 IPv4、IPv6 用户规则 |
| `/etc/default/ufw`、`/etc/ufw/ufw.conf` | UFW 的默认策略、启用状态等设置 |

AppImage 的程序、Python、GTK 和其他运行资源留在包内或临时运行副本中，启动流程不会将它们安装到宿主 `/usr/`。副本中的 `etc/gufw/app_profiles` 是应用自带的预设规则资源，与宿主 `/etc/gufw/*.profile` 保存的个人配置方案用途不同。

配置和日志路径见 [Gufw 后端](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/ufw_backend.py#L21-L28)，初始化条件见 [默认配置读取](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/firewall.py#L264-L291)，UFW 规则位置见 [官方框架手册](https://manpages.ubuntu.com/manpages/noble/man8/ufw-framework.8.html)。

## 界面颜色与监听报告

Rules（规则）和 Report（报告）的策略颜色含义如下：

| 颜色 | 策略含义 |
| --- | --- |
| 橙红色 | 允许（ALLOW） |
| 绿色 | 阻止（DENY） |
| 蓝色 | 拒绝（REJECT） |
| 橙黄色 | 限速（LIMIT） |

颜色表示规则策略，不表示当前正在传输数据。Report 的普通主题文字色表示没有单独标记策略颜色，不能据此判断端口是否放行或是否正在使用。防火墙是否启用，应看状态开关和 UFW 状态。

Report 来自 `ufw show listening`，显示监听端口和对应程序。程序正在监听，不等于已有外部连接或正在传输流量；删除防火墙规则不会关闭程序的监听端口，因此删除后仍能在 Report 看到该程序。

源码依据：[策略颜色](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/view/gufw.py#L657-L666)、[Report 着色](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/view/listening.py#L79-L96)、[监听数据来源](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/ufw_backend.py#L482-L525)。

## 配置文件：家庭、办公室与公共

家庭、办公室、公共是同一套 UFW 的不同配置方案，分别保存启用状态、默认策略和 Gufw 管理的规则。默认创建时，公共使用拒绝传入（REJECT），办公室使用阻止传入（DENY），家庭继承创建时的系统策略；这些设置可以修改，以当前配置为准。

切换配置会移除上一配置中 Gufw 能识别的自有规则，再加载所选配置保存的规则，并应用其状态和默认策略。切换会实际改变系统防火墙，不能当成只切换列表分类。通过命令行或其他工具创建、没有 Gufw 编辑参数的规则通常会保留；配置切换不会为它们补齐编辑参数。

在家庭配置下删除某条规则，会删除系统当前对应的 UFW 规则。若另一个配置保存了等效规则，切换过去时可能重新加载；外部工具再次执行配置也可能重建规则。是否发生应按实际规则内容核对，不能仅凭配置名称或重复编号判断删除无效。

首选项中的“显示配置文件”只控制配置选择器等界面的显示；隐藏选择器不会删除这些配置。日志中的 `Home > 家庭` 等记录来自上游按界面语言处理配置名称的逻辑，不代表新建了另一套防火墙，也不能仅凭重复日志判定规则被重建。

源码依据：[配置切换](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/firewall.py#L50-L97)、[默认配置与名称处理](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/firewall.py#L264-L318)、[显示配置开关](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/view/preferences.py#L182-L200)。

### 只保留一个配置与清理旧配置

只使用公共方案时，可以在 Gufw 首选项中删除未使用的家庭、办公室方案。删除的是所选方案的配置文件，不会因此清空当前公共方案的实际 UFW 规则；界面也会阻止删除当前正在使用的方案。

保留公共的 `.profile`，且 `gufw.cfg` 仍指向它时，正常重启不会自动补回家庭、办公室。若所有 `.profile` 都被清理，后续正常启动会重新初始化三套方案；若当前方案记录为空或指向丢失的文件，也可能回退或重建相应方案。

完全不用 Gufw 时，可在退出程序后清理不再需要的 `/etc/gufw/gufw.cfg` 和 `*.profile`，这会丢失相应偏好与方案。不要把整个 `/etc/gufw/` 一概当作缓存：系统安装的版本还可能在其中保存 `app_profiles` 预设资源。

清理 Gufw 配置不等于卸载、关闭或重置 UFW，也不会自动清空系统当前的防火墙规则。`/etc/ufw/` 保存实际防火墙配置，不能混作 Gufw 界面缓存删除。

源码依据：[当前方案删除保护](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/view/preferences.py#L148-L160)、[配置删除入口](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/firewall.py#L107-L109)、[配置文件删除](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/ufw_backend.py#L290-L295)、[初始化与回退](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/firewall.py#L264-L291)。

## 规则编辑与删除限制

编辑规则时，如果出现“不变的规则／你不能编辑从 ufw 上添加的规则”，表示这条规则没有匹配到 Gufw 保存的编辑参数。常见于通过 `ufw` 命令行或其他工具添加的规则；Gufw 配置记录缺失或与当前规则不匹配时，也可能出现同一提示。

- 通过 Gufw 创建，且能与当前配置中保存的编辑参数匹配的规则，可以在界面编辑。
- 缺少这些信息的规则仍可在 Gufw 中显示和删除；删除按规则编号调用 UFW，不要求编辑参数。
- 该提示只限制编辑，不会删除或停用现有规则。已有规则可继续用原工具管理，直接去掉弹窗也不能补齐编辑参数。

这是上游的规则管理方式。源码依据：[编辑入口](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/view/gufw.py#L523-L529)、[配置记录匹配](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/firewall.py#L320-L352)、[删除实现](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/ufw_backend.py#L450-L458)。

### 删除后如何确认

删除前后可用下列只读命令查看 UFW 状态和带编号的规则；启用状态下会列出规则：

```bash
sudo ufw status numbered
```

- 对照规则内容，包括策略、协议、方向、端口、地址、接口以及 IPv4／IPv6，不只看编号。删除后后续编号会变化，同一个编号可能已经对应另一条规则。
- 按编号删除只移除指定的一条规则；IPv4 与 IPv6、重复规则或其他范围相近的规则可能分别存在。
- 判断规则是否删除，应看 Rules 和 UFW 规则内容；Report 中仍有监听程序不代表删除失败。
- 某条规则消失也不表示相关端口一定不可访问；其他规则和默认策略仍会影响放行结果。

命令与按编号删除的含义见 [UFW 官方手册](https://manpages.ubuntu.com/manpages/noble/man8/ufw.8.html)。

## 配置文件导入与导出

文件菜单可导入、导出 Gufw 的 `.profile` 配置文件。文件选择器默认打开启动用户的主目录，也可以自行选择其他持久目录。

Gufw 以 root 运行，对话框通过 `PKEXEC_UID` 或 `SUDO_UID` 查询启动用户的主目录；没有有效启动用户信息时，使用当前运行账号的主目录，再回退到根目录。它不再跟随读取包内预设规则时的工作目录。AppImage 的 `/tmp/gufw-runtime.*` 只用于运行副本，程序退出后会清理，不应作为导出文件的保存位置。

导出的 `.profile` 是所选 Gufw 方案的副本。上游只保存带有 Gufw 编辑参数的规则，不能把它当作通过命令行或其他工具创建的全部 UFW 规则的完整备份。依据见 [方案写入逻辑](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/model/ufw_backend.py#L187-L229)。

## 版本元数据

公共签名 APT 下载入口返回实际 Gufw DEB 的完整版本，并保存同次来源版本文件；公共封装入口把该版本写入 `dist/version.txt`。GitHub Actions 在构建脚本成功退出后使用该文件发布 `gufw.AppImage` 并更新软件版本清单。

## 实机验证

### 2026-11-17：用户实机验证通过

用户已确认 Gufw AppImage 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| 启动与图形授权 | 图形授权后正常打开主窗口。 |
| 中文界面与深色主题 | 中文菜单、深色主窗口及列表文字显示正常。 |
| X11 中文输入 | 授权后的界面文本框可以输入中文。 |
| 规则与监听报告 | 规则列表及监听端口、应用程序报告正常显示。 |
| 导出窗口默认目录 | 修复后默认打开启动用户的主目录。 |

#### 运行观察

- 实机删除操作后，界面显示“规则被删除”，日志记录了 UFW 删除命令调用。
- 删除未使用的家庭、办公室方案后，界面保持选中公共方案并显示当前规则列表。

## 本次核对

已静态核对 Ubuntu 官方软件包、现有依赖解包及启动链：原生运行库改用 Ubuntu 24.04，Gufw 保留官方当前的架构无关应用包。保留已有主 desktop 选择、资源补丁、临时副本和提权方式。公共签名下载入口的原八参数调用保持原有包架构及索引选择，新增第九参数只由本应用显式使用。后续正式产物已发布，用户实测图形授权及主窗口启动通过。

针对本次中文 locale、主题与图标修复，已在临时副本、独立 Xvfb 和 D-Bus 中验证 GTK 界面的中文菜单、深色背景、普通文本主题前景色和三个窗口的包内图标；四种会话的授权环境传递均通过。独立 IBus 测试引擎经 XIM 提交“你好”，包内 GTK 文本框实际收到中文插入事件；这项隔离测试仅验证输入通道，后续用户已实测图形授权后的 X11 中文输入成功。资源准备脚本重复执行保持幂等。

隔离测试只加载 GTK 界面和文本框，不执行真实 ufw 后端，也不改变宿主规则。用户后续实测已确认图形授权后的深色主窗口、中文菜单与 X11 中文输入正常。上游中文翻译仍有缺项，例如 `Rules`、`Report`、`Routed`，本次保留上游翻译原文。

## 修复记录

### 2026-11-17

- 故障现象为第二次 linuxdeploy 自动选择 Python 的 desktop，随后以 `Icon 名无法放到 AppDir 根目录` 退出。[构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/43902110165/job/133421328107)
- 根因是 `build_gufw.sh` 没有指定主 desktop，而 Python 运行包同时带入了 `python3.14.desktop`。
- 修复位于 `build_gufw.sh`，为第二次 linuxdeploy 增加 Gufw 的 `--desktop-file` 参数。对应差异、固定路径和故障原文分别记录在 [模板差异](./docs/template-deviations.md)、[固定配置](./docs/hardcoded.md)和[构建故障记录](./docs/error.md)。
- 已核对失败日志、官方 desktop、参数路径及调用顺序。后续正式产物已发布，用户实测图形授权及主窗口启动通过。

### GLIBC 运行库兼容性

- 已有运行反馈在 `import gi` 阶段失败：包内 `libglib-2.0.so.0` 要求宿主未提供的 `GLIBC_2.43`。这是原生运行库的兼容基线问题；启动脚本此前附带的 `/tmp` 提示不能作为禁止执行的证据。下列原始错误仅把随机临时目录名统一为 `gufw-runtime.XXXXXX`：

```text
Traceback (most recent call last):
  File "<string>", line 1, in <module>
    import gi; gi.require_version("Gtk", "3.0"); from gi.repository import Gtk
    ^^^^^^^^^
  File "/tmp/gufw-runtime.XXXXXX/usr/lib/python3/dist-packages/gi/__init__.py", line 40, in <module>
    from . import _gi
ImportError: /usr/lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.43' not found (required by /tmp/gufw-runtime.XXXXXX/usr/lib/libglib-2.0.so.0)
复制出的 Gufw 运行库无法加载。若 /tmp 禁止执行程序，root 同样无法启动。
```

- 修复将 Gufw Job 改为 Ubuntu 24.04，并将原生运行库与界面应用的来源分开。Ubuntu 24.04 自带的 Gufw 24.04 仍强依赖 WebKit，现有资源补丁也不适配其教程路径，因此不能仅降低 runner 后直接改装该旧应用包。保留 Ubuntu 官方当前 Gufw 的 `all` 包，避免引入旧 WebKit 的程序与 helper 部署问题。
- Ubuntu 官方包资料：[Noble glibc](https://packages.ubuntu.com/noble/libc6)、[Noble PyGObject](https://packages.ubuntu.com/noble/python3-gi)、[Noble GTK3](https://packages.ubuntu.com/noble/libgtk-3-0t64)、[Noble Gufw](https://packages.ubuntu.com/noble/gufw)、[Resolute Gufw](https://packages.ubuntu.com/resolute/gufw)。索引和公钥来自 [Ubuntu 官方归档](https://archive.ubuntu.com/ubuntu/project/)。
- `AppRun` 保留原始导入错误，并明确提示 GLIBC 缺失属于运行库兼容问题；不再把所有导入失败都附带解释为 `/tmp` 禁止执行。未引入 Python 插件，也未替换宿主 glibc。

### 中文 locale、深色主题、窗口图标与 X11 输入

- 用户实测主窗口可打开，但出现 `Locale not supported by C library. Using the fallback 'C' locale.`，菜单英文、部分 Python 文本中文；同时主窗口、首选项和关于窗口请求不存在的宿主路径 `/usr/share/icons/hicolor/48x48/apps/gufw.png`。
- 隔离复现确认：继承的 `LC_ALL` 优先于 `LANG`。C locale 下 GTK/C 翻译未启用，而 Python gettext 仍按 `LANGUAGE` 加载中文，造成混合界面。`AppRun` 显式设置并向提权后的进程传递 `LC_ALL=zh_CN.UTF-8`，与包内 locale 一致。
- GTK 插件在无法取得桌面颜色偏好时会回退为亮色；本应用按已选择的深色界面设置 `GTK_THEME=Adwaita:dark`。图标补丁只把三个 UI 文件的固定 `icon` 路径改为 `icon_name=gufw`，不改图标内容。普通规则和日志的固定黑色前景改为不指定颜色，由 GTK 主题提供前景色。
- X11 的 root 输入优先使用已有 Fcitx／IBus XIM 会话，避免直接连接普通用户的输入法 D-Bus。原生 Wayland 与未配置 XIM 的会话保持原有模块。依据见 [Fcitx 官方 root 程序说明](https://fcitx-im.org/wiki/FAQ/en#Root_application_under_normal_user_X)。
- 测试以正式发布资产及官方 SHA-256 校验后的临时副本进行；没有改动用户附件、宿主配置或防火墙规则。实机验证结果见[实机验证](#实机验证)，隔离检查过程见“本次核对”。

### 启动 Shell 的 locale 切换顺序

- 后续用户实测确认深色、中文菜单和 X11 中文输入正常，但启动 Shell 在 `AppRun.wrapped` 第 182 行输出 `warning: setlocale: LC_ALL: cannot change locale (zh_CN.UTF-8): No such file or directory`。
- 原处理在 `apply_tree` 准备包内 `LOCPATH` 之前，全局设置 `LC_ALL`，使 Bash 在尚未取得包内 locale 数据路径时就立即尝试切换中文 locale；这条警告与随后界面显示中文并不矛盾。隔离复现还确认，仅交换两个 `export` 的顺序不足以解决 Bash 当前进程的 locale 路径问题。
- 现统一使用 `GUI_LOCALE` 参数数组，通过 `/usr/bin/env` 只为界面子进程设置中文配置。GTK 导入检查、root 直接启动和图形授权后的启动均先取得对应目录的 `LOCPATH`，再带入同一套中文配置；启动 Shell 沿用宿主 locale，不隐藏或重定向警告。
- 使用附件内的 locale 数据及指向空目录的初始 `LOCPATH` 模拟宿主未提供中文 locale。旧脚本可复现同一警告；修复后的挂载目录、临时副本、root 直接启动及授权环境传递检查通过，中文 locale 正确且无该警告。Shell 语法检查通过，没有执行真实 ufw 后端。

### 配置文件导入与导出默认目录

- 用户实机发现导出对话框默认打开 `/tmp/gufw-runtime.XXXXXX/etc/gufw/app_profiles`，与临时运行副本的资源目录相同。
- 上游 `Add._load_from_files` 使用 `os.chdir(DIR_PROFILES)`，会改变整个进程的工作目录；打包时该目录已映射到运行副本。导入、导出共用的 `_file_dialog` 没有指定起始目录，因此对话框会进入包内资源目录。保存在运行副本中的文件会随程序退出清理。
- 修复位于 `patches/prepare_gufw_sources.py`：为配置文件选择器显式指定启动用户的主目录，按授权器提供的 UID 查询系统账号；目录不存在时逐级回退。补丁识别已有插入内容，避免重复添加；插入点不唯一时明确退出。
- 后续用户实机截图确认，导出窗口默认打开启动用户的主目录；结果见[实机验证](#实机验证)。
- 已核对当前上游调用位置、现有提权环境传递、GTK 目录接口及完整补丁差异。依据：[预设规则读取](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/view/add.py#L503-L508)、[文件对话框](https://github.com/costales/gufw/blob/51397e7d6d660194d4d8d4c654f0ab89f67c7a6a/gufw/gufw/view/gufw.py#L670-L698)、[GTK 目录接口](https://docs.gtk.org/gtk3/method.FileChooser.set_current_folder.html)、[pkexec 启动用户信息](https://www.freedesktop.org/software/polkit/docs/latest/pkexec.1.html)、[sudo 环境变量](https://manpages.ubuntu.com/manpages/noble/man8/sudo.8.html)。
