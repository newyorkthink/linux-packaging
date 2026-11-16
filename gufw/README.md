# Gufw AppImage

## 用途与产物

本目录在 Ubuntu 26.04 构建 Gufw AppImage，产物为 `dist/gufw.AppImage`。版本取构建当时 Ubuntu 仓库里的 `gufw`，不写死版本号。界面和 Python 运行库在包内；防火墙规则仍由宿主机的 `/usr/sbin/ufw` 执行。

## 技术栈与打包方式

Gufw 26.04 是 GTK3、Python 3 和 PyGObject 程序，并且必须以 root 运行。脚本以 [GTK Ubuntu 仓库模板](../templates/appimage/linuxdeploy-gtk-apt.sh) 为底稿，但标准生成器覆盖不了 Python 运行包、宿主命令隔离和 root 启动，因此拟采用专用流程。例外范围见 [模板差异](./docs/template-deviations.md)。固定路径见 [固定配置](./docs/hardcoded.md)。

公共 APT 入口安装依赖，再按名称解包当前的 `gufw` 以及解释器、标准库、PyGObject、GI typelib 和 GTK3。公共解包入口不会递归解依赖，缺少的包由构建脚本显式列出。解释器动态链接共享 `libpython` 时，再追加该库所属的软件包；静态链接时不追加，也不因此中止构建。linuxdeploy 使用 GTK 插件；解释器、`_gi.so` 和 `libgtk-3.so.0` 用 `--deploy-deps-only` 收集已经在 AppDir 里的文件的依赖，不使用 `--executable`。第二次部署显式指定 `usr/share/applications/gufw.desktop`，由该入口选择 Gufw 图标。

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

公共 APT 解包入口返回实际主包版本，公共封装入口把它写入 `dist/version.txt`。GitHub Actions 在构建脚本成功退出后使用该文件发布 `gufw.AppImage` 并更新软件版本清单。

## 本次核对

已对照上游源码、官方 GTK 插件和 Ubuntu resolute 的 Python 软件包资料，人工静态核对入口、依赖、资源路径、宿主命令环境及工作流接入。首次构建在第二次 linuxdeploy 的中间封装阶段因主 desktop 选择错误失败。本次修复后的构建、图形启动、临时副本、授权和规则操作尚未验证。

## 修复记录

### 2026-11-17

- 故障现象为第二次 linuxdeploy 自动选择 Python 的 desktop，随后以 `Icon 名无法放到 AppDir 根目录` 退出。[构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/43902110165/job/133421328107)
- 根因是 `build_gufw.sh` 没有指定主 desktop，而 Python 运行包同时带入了 `python3.14.desktop`。
- 修复位于 `build_gufw.sh`，为第二次 linuxdeploy 增加 Gufw 的 `--desktop-file` 参数。对应差异、固定路径和故障原文分别记录在 [模板差异](./docs/template-deviations.md)、[固定配置](./docs/hardcoded.md)和[构建故障记录](./docs/error.md)。
- 已核对失败日志、官方 desktop、参数路径及调用顺序。修复后的正式构建结果尚未验证。
