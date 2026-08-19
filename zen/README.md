# Zen AppImage

本目录用于构建 Zen Ad-Blocker 的 AnyLinux AppImage。

## 当前最终基线

当前版本已经恢复为 **Zen 官方原版程序**：

- 直接使用 Zen 官方 GitHub Release 提供的 `Zen_linux_amd64_noselfupdate.tar.gz`；
- 不再克隆 Zen 源码进行二次编译；
- 不再应用任何 `.patch`；
- 不再修改 Zen 的 HTTP / HTTPS / WebSocket / MITM / PAC / 排除列表等网络逻辑；
- 不再写死 `127.0.0.1:1080` 或其他 SpoofDPI 上游地址；
- 不再使用 `zen_toggle.so`、`LD_PRELOAD` 或 GTK hook 修改窗口行为；
- Zen 的代理、过滤、HTTPS 排除、托盘、窗口显示/隐藏等行为全部以官方版本为准。

本仓库只负责把官方 Linux 二进制及必要运行库封装成 AppImage。

## 构建来源

`build_zen.sh` 每次读取：

```text
https://api.github.com/repos/irbis-sh/zen-desktop/releases/latest
```

并从最新正式 Release 中选择官方资产：

```text
Zen_linux_amd64_noselfupdate.tar.gz
```

选择 `noselfupdate` 是因为最终程序由 AppImage / GitHub Release 管理更新，避免 Zen 在 AppImage 内自行替换程序文件。

如果 GitHub Release 提供 `sha256:` digest，构建脚本会在解压前校验官方资产 SHA256。

## 构建流程

```text
Zen 官方 latest Release
  ↓
下载官方 Zen_linux_amd64_noselfupdate.tar.gz
  ↓
校验 GitHub Release SHA256 digest
  ↓
直接取出官方 Zen 二进制
  ↓
quick-sharun 收集 Linux 运行库
  ↓
生成 zen.AppImage
```

**过程中不修改 Zen 可执行文件内容。**

## 当前目录

```text
zen/
├── build_zen.sh
└── README.md
```

之前用于实验的以下内容已经删除，不再参与构建：

```text
patches/
zen_toggle.c
zen_toggle.so
```

## AppImage 兼容层

`build_zen.sh` 仍保留一个 AppImage 侧的 `pkexec` 转发脚本。

它只用于把 Zen 官方发起的系统管理调用转发到宿主机：

```text
/usr/bin/pkexec
/usr/sbin/update-ca-certificates
```

原因是 AppImage 内部 PATH 与宿主系统不同，提权后不能依赖 AppImage 内路径去执行宿主机证书更新命令。

这个包装器：

- 不修改 Zen 二进制；
- 不修改 Zen 网络代理逻辑；
- 不修改过滤规则；
- 不修改 DAE / SpoofDPI / Hysteria2；
- 只有用户主动使用 Zen 官方 CA 安装 / 卸载功能时才涉及宿主系统证书信任库。

## DAE / SpoofDPI

当前 Zen AppImage **不包含任何针对 DAE 或 SpoofDPI 的定制代码**。

因此不要再把下面这种行为理解为 Zen AppImage 自带能力：

```text
Zen -> 固定 SOCKS5 127.0.0.1:1080
```

该逻辑已经删除。

如果以后需要让 Zen 与 DAE / SpoofDPI 组合使用，应在外部代理 / 路由层处理，不再修改 Zen 官方程序。

## 原则

以后默认保持以下稳定基线：

1. Zen 使用官方发布二进制；
2. 不维护 Zen fork；
3. 不增加 Zen 源码 patch；
4. 不使用 preload hook 修改 Zen；
5. 只有明确要求并单独确认后，才允许再次引入任何程序行为修改。
