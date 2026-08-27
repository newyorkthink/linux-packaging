# TraeWork Linux 移植

本目录用于构建 **TraeWork Linux x86_64 AppImage**。当前方案已接入仓库统一 `.github/workflows/build.yml`，与其他 AppImage 使用同一个主构建入口、同一个 `latest` Release。

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
| Release 产物 | `trae-work.AppImage` |

TraeWork Windows 安装包版本、构建号、下载地址和 SHA256 固定在 `build_trae-work.sh` 中；Linux Trae 版本从当前 AUR `trae` 的 `PKGBUILD` 解析，不写死 Linux 下载地址。

## 下载与运行

普通用户直接下载 `latest` Release 中的 AppImage，不需要下载 Actions Artifact，也不需要自行构建：

```text
https://github.com/newyorkthink/linux-packaging/releases/latest/download/trae-work.AppImage
```

在 **Linux x86_64 终端**执行：

```bash
# 给下载后的 AppImage 添加执行权限
chmod +x trae-work.AppImage

# 直接启动 TraeWork
./trae-work.AppImage
```

## 已完成验证

当前发布包已经通过以下检查：

- 构建脚本完成 Windows TraeWork 安装包 SHA256 校验；
- Linux Trae 运行时按 AUR `PKGBUILD` 中的校验信息下载并校验；
- `libaha_net.so` 在进入 `quick-sharun` 前检查动态库依赖，存在 `not found` 时直接失败；
- `quick-sharun` 成功生成非空 `dist/trae-work.AppImage`；
- GitHub Actions 使用 Xvfb 启动 AppImage 30 秒，进程存活至超时返回 `124` 视为基础启动通过；
- smoke test 会检查历史移植中的 `unknown service: lite` / `unknown service: solo-lite`，出现时直接判定失败；
- 已在真实 Linux 桌面环境完成手动启动验证。

`latest` Release 中的 `trae-work.AppImage` 是普通用户使用的正式下载入口。

## 构建流程

`build_trae-work.sh` 的实际流程如下：

1. 清理本次构建目录并检查 CPU 架构，只允许 `x86_64`。
2. 安装 Electron/AppImage、解包和 Xvfb 测试所需依赖。
3. 克隆 AUR `trae`，解析当前 Linux Trae 版本、下载地址和校验值。
4. 下载 TraeWork Windows x64 安装包并校验 SHA256。
5. 优先使用 `innoextract` 解包；若未得到完整 `resources/app`，则通过 Wine 按 Inno 静默安装方式解到临时目录。
6. 下载并校验 Linux Trae 运行时。
7. 先复制完整 Linux Electron 外壳，再用 TraeWork Windows `resources/app` 替换产品层。
8. 从 Linux Trae 中覆盖或补齐 ELF、`.so`、`.node` 原生组件，并单独处理关键兼容组件。
9. 生成独立 `trae-work` 启动入口、Desktop 文件和诊断报告。
10. 使用 `quick-sharun` 生成 `dist/trae-work.AppImage`。
11. 主 workflow 使用 Xvfb 对生成的 AppImage 执行 30 秒基础启动测试。
12. 只有构建和 smoke test 都通过后，才覆盖上传 `latest` Release 中的 `trae-work.AppImage`。

该方案不是直接运行 Windows Electron 二进制，而是复用 Linux Electron 运行时，只迁移 TraeWork 产品层，并尽可能替换为 Linux 原生组件。

## GitHub Actions

TraeWork 已并入统一主 workflow：

```text
.github/workflows/build.yml
```

触发规则与仓库其他 AppImage 一致：

- `trae-work/**` 推送到 `main` 时，只选择 TraeWork 构建任务；
- `workflow_dispatch` 可以单独选择 `trae-work/build_trae-work.sh`；
- `workflow_dispatch` 选择 `all` 时与其他 AppImage 一起构建；
- 每日定时 `all` 构建会包含 TraeWork；
- 已删除旧的 `.github/workflows/trae-work-test.yml`，避免同一变更重复触发两套 TraeWork 构建。

为了避免仅因同时修改主 workflow 和某个具体项目而把全部 AppImage 重复构建，主 workflow 会优先按本次实际变更的项目目录选择任务；只有主 `build.yml` 单独变化且没有任何具体项目被选中时，才回退为全量构建。共享 `.github/actions/build-anylinux/**` 变化仍会全量构建。

## 自动测试判断标准

Xvfb smoke test 主要检查历史移植中最关键的 `lite / solo-lite` 服务兼容问题。

测试会：

- 启动 `trae-work.AppImage` 30 秒；
- 保存启动日志到 `dist/smoke-test.log`；
- 检查是否出现 `unknown service: lite` 或 `unknown service: solo-lite`；
- 将 Windows TraeWork 与 Linux Trae 的 ai-agent 相关信息写入 `dist/port-report.txt`；
- 如果进程持续运行到 30 秒超时，`timeout` 返回码 `124` 被视为基础启动存活；
- 如果出现已知 `lite / solo-lite` 错误，或者程序以其他异常状态提前退出，则 workflow 失败并且不会发布新的 Release 产物。

## 本地构建

本构建脚本按照 **Arch Linux x86_64 + `yay` + `quick-sharun`** 环境编写。若需要本地复现，应在满足这些依赖的 Arch Linux 环境中执行，不应直接把脚本当作 Debian/Kali 安装脚本使用。

在 **Arch Linux x86_64 终端、仓库根目录**执行：

```bash
# 进入 TraeWork 构建目录
cd trae-work

# 确保构建脚本具有执行权限
chmod +x build_trae-work.sh

# 执行 TraeWork 构建
./build_trae-work.sh
```

构建成功后主要文件位于：

```text
dist/trae-work.AppImage
dist/port-report.txt
```

## 验证边界

30 秒自动 smoke test 用于阻止明显的基础启动回归，不等同于完整功能测试。账号登录、项目打开、Agent / SOLO 实际任务、项目索引、终端、网络请求及长时间运行稳定性仍属于真实桌面使用验证范围。

## 目录文件

```text
trae-work/
├── README.md
└── build_trae-work.sh

.github/workflows/
└── build.yml
```
