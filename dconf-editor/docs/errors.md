# dconf Editor 故障记录

## 45.0.1 读取 GSettings schema 路径时段错误

- 发生阶段：AppImage 启动和运行期间。旧产物多次出现以下断言，随后段错误。

  ```text
  source_manager_try_prepend_dir: assertion 'schemas_dir != NULL' failed
  Segmentation fault (core dumped)
  ```

- 上游原因：[45.0.1 的 `source-manager.vala`](https://github.com/GNOME/dconf-editor/blob/45.0.1/editor/source-manager.vala) 按 `XDG_DATA_DIRS` 的目录数遍历 `GSETTINGS_SCHEMA_DIR` 拆出的数组。前者较长时可能越界。旧、新产物均包含 `gschemas.compiled`。
- 官方修复：[49.rc 发布说明](https://github.com/GNOME/dconf-editor/blob/49.0/NEWS) 记录了该崩溃修复，[49.0 源码](https://github.com/GNOME/dconf-editor/blob/49.0/editor/source-manager.vala) 按 `extra_schema_dirs` 自身长度遍历。
- 打包处理：dconf Editor 的构建环境改用 Ubuntu 26.04，从[官方 APT 仓库](https://packages.ubuntu.com/resolute/dconf-editor)动态获取当前版本。该方案的后续启动故障见下节。

## 49.0 AppImage 加载库时缺少 GLIBC_2.43

Ubuntu 26.04 构建的 49.0 AppImage 下载并校验成功，但包内 `libglib-2.0.so.0` 和 `liblcms2.so.2` 在加载时分别从 `libc.so.6` 和 `libm.so.6` 请求 `GLIBC_2.43`，启动随即失败。

```text
libc.so.6: version `GLIBC_2.43' not found (required by …/usr/lib/libglib-2.0.so.0)
libm.so.6: version `GLIBC_2.43' not found (required by …/usr/lib/liblcms2.so.2)
```

构建恢复到 Ubuntu 24.04，采用官方 APT 提供的 45.0.1 DEB。AppRun 通过 `exec env -u GSETTINGS_SCHEMA_DIR` 启动包内图形程序，绕过上文记录的上游缺陷。后续发布的 45.0.1 AppImage 已通过实机启动检查。

## 45.0.1 启动后显示英文，GTK 回退到 C locale

- 现象：AppImage 可以打开，界面显示英文，终端提示 `Using the fallback 'C' locale.`。
- 译文：此前只接入标准中文 locale 配置，未恢复旧包的中文译文部署和路径重定位。构建时从 Ubuntu 中文语言包复制译文，封装前复用旧版 ELF 路径补丁，AppRun 从包内根目录启动。
- locale：保留标准 locale 生成和语言设置，恢复旧版使用的 `LC_ALL=zh_CN.UTF-8`。新产物已实测可启动，简体中文界面显示正常。启动时仍出现 Bash 警告 `setlocale: LC_ALL: cannot change locale (zh_CN.UTF-8): No such file or directory`，本次未影响中文显示。
- 防崩溃入口继续清除 `GSETTINGS_SCHEMA_DIR`。
- 后续处理：将 `LC_ALL=zh_CN.UTF-8` 从 Bash 的独立导出移到最终启动命令，仅传给应用进程。中文资源和防崩溃处理继续沿用。最终结果见 [实机验证](../README.md#实机验证)。

## Ubuntu 24.04 构建无法下载完整 Adwaita 图标包

- 现象：[构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/41749188382/job/126309773462)中 APT 报错 `Can't select candidate version from package adwaita-icon-theme-full as it has no candidate`，构建以状态码 100 退出。
- 处理：从 dconf Editor 的主题下载清单移除 `adwaita-icon-theme-full`，保留 `adwaita-icon-theme`、`gnome-themes-extra-data` 和 `GTK_THEME=Adwaita-dark`。最终结果见 [实机验证](../README.md#实机验证)。

## dconf CLI 软链接误启动图形界面

- 现象：启动 VS Code 时，额外打开 dconf Editor 图形窗口。
- 触发条件：名为 dconf 的外部软链接指向本 AppImage，而其他程序通过该入口调用 dconf CLI。
- 调用依据：VS Code 的系统代理组件会执行 `dconf watch /system/proxy/`。
- 原因：模板重写删除了原有的 ARGV0 分派，导致命令行调用进入图形界面。
- 修复：原样恢复旧版四行分派代码，放在三个基础搜索路径设置之后、GTK 配置之前，并采用“本程序专属处理”注释。现有图形界面配置保持原样。
