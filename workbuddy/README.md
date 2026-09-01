# WorkBuddy AppImage

本目录维护 **WorkBuddy Linux x86_64 AppImage** 的 AUR 审计、构建和发布。

当前稳定流程已经完成：AUR 预检查 → Linux 运行时适配 → AppImage 构建 → Xvfb smoke test → `latest` Release 发布。

当前发布版本已实际验证：

- AppImage 可以正常启动；
- Linux native module 可以正常加载；
- i3 / i3bar 托盘小图标可以正常显示；
- GitHub Actions 构建、smoke test 和 Release 发布流程可以正常完成。

## 目录结构

```text
workbuddy/
├── README.md
├── build_workbuddy.sh
└── test_workbuddy_aur.sh
```

相关 GitHub Actions：

```text
.github/workflows/build.yml
```

各文件职责保持独立：

- `test_workbuddy_aur.sh`：只读审计当前实际构建使用的 AUR `workbuddy` 配方、来源、版本和高风险构建模式；
- `build_workbuddy.sh`：安装当前 AUR `workbuddy`，完成 Linux runtime 适配并生成 `workbuddy.AppImage`；
- `build.yml`：主 `Build AppImages` workflow 中保留 WorkBuddy 独立 Job，负责构建、Xvfb smoke test 和 `latest` Release 发布。

## AUR 构建来源

当前构建与审计统一固定使用 AUR `workbuddy`，不做候选配方比较或自动切换，确保审计对象与实际 AppImage 构建来源完全一致。WorkBuddy 版本不在本仓库锁定，始终读取当前 AUR 实际版本。

## 当前构建基线

`build_workbuddy.sh` 当前按以下固定流程工作：

1. 先执行 `test_workbuddy_aur.sh`，审计失败则停止构建；
2. 安装当前 AUR `workbuddy`，从实际安装结果读取版本，不在本仓库重复维护 WorkBuddy 版本号；
3. 从 `pacman` 的当前安装文件清单动态定位 `app.asar.unpacked/package.json`，以其所在目录作为应用 payload，不锁定 `/opt` 下的目录名称或大小写；
4. 复制完整系统 Electron runtime，并保留 Electron 自带的 `locales`、`resources`、snapshot 等运行文件；
5. 如果 AUR 为系统安装写死了实际资源根目录，则将该路径恢复为 `process.resourcesPath`，适配 AppImage 内部目录；未写死时不修改应用代码；
6. 仅保留 Linux x86_64 所需的 `node-pty` 平台包，并检查 `node-pty` 与 `better-sqlite3` 的 Linux ELF native module；
7. 复用 AUR desktop 元数据和官方 PNG 图标；
8. 使用 `quick-sharun` 部署 Electron、GTK、NSS、输入法、OpenGL、Vulkan、PipeWire 等运行依赖；
9. 生成最终单文件 `workbuddy.AppImage`；
10. GitHub Actions 在 Xvfb 下执行启动 smoke test，通过后发布到 `latest` Release。

## i3 / AppIndicator 托盘图标

WorkBuddy 的 Linux 适配会从磁盘路径读取托盘图标：

```text
path.dirname(process.resourcesPath)/.workbuddy-linux/workbuddy.png
```

当前 AppImage 中：

```text
process.resourcesPath = AppDir/bin/resources
```

因此构建脚本固定将官方 WorkBuddy PNG 同时放到：

```text
AppDir/bin/.workbuddy-linux/workbuddy.png
```

构建阶段会检查该文件必须存在且非空，避免再次生成“主程序正常但 i3bar 托盘缺图标”的 AppImage。

## 用户数据

WorkBuddy 用户数据继续由应用写入用户目录：

```text
~/.workbuddy/
```

AppImage / AppDir 只包含程序本体和运行依赖，不应把 `~/.workbuddy/` 打入 AppImage，也不应在构建过程中上传该目录。

`~/.workbuddy/` 可能包含账号会话、Connector token、自定义模型 API Key、对话历史、本地文件索引和其他私有数据。

## 发布

GitHub Actions 发布文件名固定为：

```text
workbuddy.AppImage
```

发布位置：

```text
https://github.com/newyorkthink/linux-packaging/releases/tag/latest
```

当前 `build_workbuddy.sh`、`test_workbuddy_aur.sh` 和 `build.yml` 中的 WorkBuddy 独立 Job 已作为稳定基线。除非上游 WorkBuddy、AUR 配方、Electron runtime 或 Linux 适配路径发生变化，否则不应为整理文档而改动这些已验证内容。
