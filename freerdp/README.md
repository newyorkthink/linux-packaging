# FreeRDP AppImage

## 用途与产物

本目录将 FreeRDP 3 的 Linux 客户端及相关工具重新打包为 AppImage，主运行入口为 `xfreerdp3`。

- 上游项目：FreeRDP / FreeRDP
- 上游软件来源：Arch Linux 官方仓库中的 `freerdp` 包
- 架构：x86_64
- 最终产物：`xfreerdp3.AppImage`
- Release 资产名：`xfreerdp3.AppImage`
- 正式构建入口：`.github/workflows/build.yml` 中的 `Build FreeRDP` Job

## 技术栈

FreeRDP 主要由 C / C++ 实现。本目录不重新编译 FreeRDP 源码，而是在 Arch Linux 构建环境中安装当前仓库提供的最新稳定 `freerdp` 包，再使用 quick-sharun 收集主程序、FreeRDP 运行库、代理插件及其动态依赖。

当前打包同时包含 `xfreerdp3`、`wlfreerdp3`、SDL 客户端、FreeRDP proxy / shadow 相关程序以及 WinPR 工具。构建脚本保留 FreeRDP proxy plugins，并通过 `PATH_MAPPING` 将运行时的 `/usr/lib/freerdp/server/proxy/plugins` 映射到 AppImage 内部目录。

## 打包方式

当前路线为 **Arch Linux + quick-sharun**：

1. 通过 `yay` 安装 FreeRDP 及当前打包所需依赖。
2. 使用 quick-sharun 收集 FreeRDP 可执行文件、动态库、proxy plugins、desktop 和图标。
3. 使用 quick-sharun 的 `PATH_MAPPING` 支持，将 FreeRDP proxy plugins 的固定系统路径映射到 AppImage 内部。
4. 由 `quick-sharun --make-appimage` 生成 `dist/xfreerdp3.AppImage`。
5. 正式 workflow 将产物发布到 `latest` Release。

应用版本由 Arch Linux 仓库中的当前稳定 `freerdp` 包动态取得，构建脚本不固定 FreeRDP 版本号。

## 运行与兼容说明

AppImage 主入口为 `xfreerdp3`，实际 RDP 参数沿用 FreeRDP 3 的命令行接口。proxy plugins 位于 AppImage 内部 `lib/freerdp/server/proxy/plugins/`，运行时由 quick-sharun 的 path-mapping 机制提供对应路径。

本项目的打包阶段在 GitHub Actions 的 Arch Linux 容器中执行；最终 AppImage 不要求用户在本机安装构建依赖。

### 2026-09-12 实际运行验证

已使用 latest Release 中生成的 `xfreerdp3.AppImage` 实际连接 Windows 10，并成功进入远程桌面。测试使用了动态分辨率、键盘抓取、PulseAudio 音频、剪贴板、自动网络配置、GDI 硬件模式以及目录共享等参数；日志中可见 RDP 图形会话初始化完成、动态虚拟通道加载、共享盘注册以及登录成功。

本次运行日志中的以下信息属于非阻断警告，实际连接已成功：

- VAAPI 初始化失败后自动回退到软件解码。
- `/cert:ignore` 会产生证书未校验警告；仅适合明确可信的本地或受控连接环境。
- 未配置默认 Kerberos realm 时会出现 Kerberos 解析警告；本次本地账户登录不受影响。
- 目录共享可能出现 `FAT_IOCTL_GET_ATTRIBUTES` / `Inappropriate ioctl for device` 警告，不影响本次 RDP 会话建立。
- 个别扩展按键可能出现 `no RDP scancode found` 映射警告，未影响本次桌面连接。
- 直接通过 `/p:` 传递密码时 FreeRDP 会提示命令行凭据暴露风险，这是 FreeRDP 自身的安全提示，不是 AppImage 打包错误。

## 修复记录

### 2026-09-12：修复 quick-sharun 完成后 Build FreeRDP 仍退出 1

- **故障现象：** 正式 `Build FreeRDP` Job 中 quick-sharun 已输出 `All done!`，但随后 Job 立即以 exit code 1 结束，没有生成并发布 AppImage。
- **根因：** 构建脚本仍检查旧位置 `AppDir/lib/path-mapping.so`；当前 quick-sharun 将 `path-mapping.so` 放在 `AppDir/lib/sharun-preload/path-mapping.so`。
- **修改文件：** `freerdp/build_freerdp.sh`。
- **修复内容：** 仅把 path-mapping helper 的存在性检查改为当前 quick-sharun 的实际目录，同时补齐构建脚本中文分区注释；FreeRDP 的程序列表、依赖、`PATH_MAPPING` 内容和打包流程保持不变。
- **最终结果：** 修复后的正式 `Build FreeRDP` Job 已成功完成，`xfreerdp3.AppImage` 已发布到 latest Release，并完成 Windows 10 实际连接验证。
