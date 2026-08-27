# TraeWork Linux 实验移植

本目录用于验证 **TraeWork 桌面版在 Linux x86_64 上运行的可行性**。

当前方案仍属于实验移植：它不属于仓库现有稳定 AppImage 构建，不参与主 `build.yml`，也不会发布到 `latest` Release。

## 当前实现

| 项目 | 当前方案 |
| --- | --- |
| TraeWork 产品层 | Windows x64 正式版 `0.1.54 / 2.3.76123` 的 `resources/app` |
| Linux 运行时 | 通过 AUR `trae` 的 `PKGBUILD` 动态取得官方 Linux x64 Trae 运行时 |
| Electron 外壳 | 保留 Linux Trae 自带 Electron 主程序和运行时文件 |
| 原生组件 | 使用 Linux Trae 中对应的 ELF、`.so`、`.node` 覆盖或补齐 Windows 产品层中的原生依赖 |
| 重点兼容组件 | `libai_agent.so`、`libckg.so`、`native-keymap` |
| 打包方式 | 仓库现有 `quick-sharun` AppImage 打包流程 |
| 支持架构 | 仅 `x86_64` |
| 主要产物 | `dist/trae-work.AppImage` |

TraeWork Windows 安装包版本、构建号、下载地址和 SHA256 均固定在 `build_trae-work.sh` 中；Linux Trae 版本则从当前 AUR `trae` 的 `PKGBUILD` 解析，不在脚本中写死 Linux 下载地址。

## 构建流程

`build_trae-work.sh` 的实际流程如下：

1. 清理本次构建目录并检查 CPU 架构，只允许 `x86_64`。
2. 安装 Electron/AppImage、解包和 Xvfb 测试所需依赖。
3. 克隆 AUR `trae`，解析当前 Linux Trae 版本、下载地址和校验值。
4. 下载 TraeWork Windows x64 安装包并校验 SHA256。
5. 优先使用 `innoextract` 解包；若当前版本不支持安装器或未得到完整 `resources/app`，则通过 Wine 按 Inno 静默安装方式解到临时目录。
6. 下载并校验 Linux Trae 运行时。
7. 先复制完整 Linux Electron 外壳，再用 TraeWork Windows `resources/app` 替换产品层。
8. 从 Linux Trae 中覆盖或补齐 ELF、`.so`、`.node` 原生组件，并单独处理关键兼容组件。
9. 生成独立的 `trae-work` 启动入口、Desktop 文件和诊断报告。
10. 使用 `quick-sharun` 生成 `dist/trae-work.AppImage`。

该方案的目的不是直接运行 Windows Electron 二进制，而是复用 Linux Electron 运行时，只迁移 TraeWork 产品层，并尽可能替换为 Linux 原生组件。

## GitHub Actions

独立测试 workflow：`.github/workflows/trae-work-test.yml`

它只在以下情况运行：

1. `trae-work/**` 发生变化并推送到 `main`；
2. `.github/workflows/trae-work-test.yml` 自身发生变化并推送到 `main`；
3. 手动执行 `workflow_dispatch`。

该 workflow：

- **没有 `schedule`**，不会每日自动运行；
- 权限只有 `contents: read`；
- 不调用主 `.github/workflows/build.yml`；
- 不修改现有 `latest` Release；
- 在 Arch Linux 容器中构建实验 AppImage；
- 构建完成后使用 Xvfb 进行 30 秒基础启动测试；
- 无论测试成功或失败，都会尝试上传实验产物和诊断日志，Artifact 保留 7 天。

## 自动测试判断标准

Xvfb smoke test 主要检查历史移植中最关键的 `lite / solo-lite` 服务兼容问题。

测试会：

- 启动 `trae-work.AppImage` 30 秒；
- 保存完整启动日志到 `dist/smoke-test.log`；
- 检查是否出现 `unknown service: lite` 或 `unknown service: solo-lite`；
- 将 Windows TraeWork 与 Linux Trae 的 ai-agent 相关信息写入 `dist/port-report.txt`；
- 如果进程持续运行到 30 秒超时，`timeout` 返回码 `124` 被视为基础启动存活，而不是功能完整验证；
- 如果出现已知 `lite / solo-lite` 错误，或者程序以其他异常状态提前退出，则 workflow 失败。

## GitHub Actions 产物

Artifact 名称格式：

```text
trae-work-linux-experimental-<run_number>
```

正常情况下包含：

```text
trae-work/dist/trae-work.AppImage
trae-work/dist/port-report.txt
trae-work/dist/smoke-test.log
```

Artifact 保留 **7 天**，不会自动上传到 `latest` Release。

## 本地构建

本构建脚本按照 **Arch Linux x86_64 + `yay` + `quick-sharun`** 环境编写。若需要本地复现，应在满足这些依赖的 Arch Linux 环境中执行，不应直接把脚本当作 Debian/Kali 安装脚本使用。

在 **Arch Linux x86_64 终端、仓库根目录**执行：

```bash
# 进入 TraeWork 构建目录
cd trae-work

# 确保构建脚本具有执行权限
chmod +x build_trae-work.sh

# 执行实验构建
./build_trae-work.sh
```

构建成功后主要文件位于：

```text
dist/trae-work.AppImage
dist/port-report.txt
```

## 验证边界

当前自动测试只能证明：

- AppImage 能否完成构建；
- Linux Electron 运行时能否启动 TraeWork 产品层；
- 30 秒基础启动期间是否再次出现已知 `lite / solo-lite` 服务错误。

当前自动测试**不能证明**以下功能已经完整可用：

- 账号登录；
- 本地项目选择和打开；
- Agent / SOLO 实际任务执行；
- 项目索引、终端、网络请求及其他完整桌面交互；
- 长时间运行稳定性。

这些功能仍需要在真实 Linux 桌面环境中继续验证。

## 目录文件

```text
trae-work/
├── README.md
└── build_trae-work.sh

.github/workflows/
└── trae-work-test.yml
```

`trae-work/` 应始终视为独立实验目录，避免与仓库现有稳定 Linux 打包项目混用。
