# Gufw AppImage

## 用途与产物

本目录在 Ubuntu 24.04 构建 Gufw AppImage，产物为 `dist/gufw.AppImage`。Python、PyGObject、GTK 和 GLib 等原生运行库只使用当前 Ubuntu 24.04 构建环境的软件包，采用 glibc 2.39 的构建基线。Gufw 界面从 Ubuntu 官方 `resolute / universe` 签名索引动态选择 `Architecture: all` 的当前包，仅解包应用文件，不把该软件源加入系统，也不安装该发行版的原生库。版本不写死；防火墙规则仍由宿主机的 `/usr/sbin/ufw` 执行。

## 技术栈与打包方式

Gufw 26.04 是 GTK3、Python 3 和 PyGObject 程序，并且必须以 root 运行。脚本以 [GTK Ubuntu 仓库模板](../templates/appimage/linuxdeploy-gtk-apt.sh) 为底稿，但标准生成器覆盖不了 Python 运行包、宿主命令隔离和 root 启动，因此拟采用专用流程。例外范围见 [模板差异](./docs/template-deviations.md)。固定路径见 [固定配置](./docs/hardcoded.md)。

公共 APT 入口只安装构建环境的依赖，再按名称解包解释器、标准库、PyGObject、GI typelib 和 GTK3。Gufw 的 DEB 由公共签名 APT 下载入口取得：使用官方归档公钥验证 `InRelease`，从 `amd64` 索引精确选择包架构 `all`，核对索引和 DEB 的 SHA-256、大小及包身份，再通过公共归档入口解包。公共解包入口不会递归解依赖，缺少的包由构建脚本显式列出。解释器动态链接共享 `libpython` 时，再追加该库所属的软件包；静态链接时不追加，也不因此中止构建。linuxdeploy 使用 GTK 插件；解释器、`_gi.so` 和 `libgtk-3.so.0` 用 `--deploy-deps-only` 收集已经在 AppDir 里的文件的依赖，不使用 `--executable`。第二次部署显式指定 `usr/share/applications/gufw.desktop`，由该入口选择 Gufw 图标。

拟采用的完整启动脚本在第二次 linuxdeploy 之前写入根 `AppRun`。官方插件若实际生成 hook，由 linuxdeploy 自行保留 `AppRun` → `AppRun.wrapped`。脚本不创建、不删除、也不要求 hook 存在。

直接运行 AppImage，启动脚本优先使用 pkexec 图形授权，取消认证时退出。图形授权不可用且有终端时回退 sudo。Gufw 以 root 运行。普通用户启动时，脚本先将 AppDir 复制到 `/tmp` 的普通目录，再启动副本中的 Python，程序退出后删除副本。整个 AppImage 已由 root 挂载时直接使用该挂载。

启动脚本保留官方 GTK3 插件生成的路径，将 `GTK_EXE_PREFIX`、`GTK_PATH` 和 `GTK_IM_MODULE_FILE` 映射到临时副本，再传给 root。插件未提供有效路径时，脚本按副本中的实际目录补齐。输入法缓存使用副本中实际存在的 `immodules.cache`，未找到时不设置 `GTK_IM_MODULE_FILE`。

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

## 版本元数据

公共签名 APT 下载入口返回实际 Gufw DEB 的完整版本，并保存同次来源版本文件；公共封装入口把该版本写入 `dist/version.txt`。GitHub Actions 在构建脚本成功退出后使用该文件发布 `gufw.AppImage` 并更新软件版本清单。

## 本次核对

已静态核对 Ubuntu 官方软件包、现有依赖解包及启动链：原生运行库改用 Ubuntu 24.04，Gufw 保留官方当前的架构无关应用包。保留已有主 desktop 选择、资源补丁、临时副本和提权方式。公共签名下载入口的原八参数调用保持原有包架构及索引选择，新增第九参数只由本应用显式使用。本次基线调整后的正式构建、图形启动、授权和规则操作尚未验证。

## 修复记录

### 2026-11-17

- 故障现象为第二次 linuxdeploy 自动选择 Python 的 desktop，随后以 `Icon 名无法放到 AppDir 根目录` 退出。[构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/43902110165/job/133421328107)
- 根因是 `build_gufw.sh` 没有指定主 desktop，而 Python 运行包同时带入了 `python3.14.desktop`。
- 修复位于 `build_gufw.sh`，为第二次 linuxdeploy 增加 Gufw 的 `--desktop-file` 参数。对应差异、固定路径和故障原文分别记录在 [模板差异](./docs/template-deviations.md)、[固定配置](./docs/hardcoded.md)和[构建故障记录](./docs/error.md)。
- 已核对失败日志、官方 desktop、参数路径及调用顺序。修复后的正式构建结果尚未验证。

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
