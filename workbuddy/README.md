# WorkBuddy Linux 适配预检查

本目录当前只做 **AUR 5.3.x 适配情况的只读预检查**，暂不直接构建或分发 WorkBuddy AppImage。

## 当前目的

先检查以下两个 AUR 包：

- `workbuddy`
- `workbuddy-bin`

`test_workbuddy_aur.sh` 会：

1. 直接克隆两个 AUR Git 仓库；
2. 只读取当前 `PKGBUILD` 与 `.SRCINFO`，**不会 source PKGBUILD，也不会运行 `makepkg` / `yay` / 安装包**；
3. 判断当前 AUR 配方是否已经跟踪 WorkBuddy `5.3.x`；
4. 输出当前 source / checksum / build function 信息；
5. 检查当前 PKGBUILD 是否包含常见的高风险执行模式；
6. 显示最近 AUR 提交以及 2026-06-09～2026-06-16 的提交记录，方便复核 `workbuddy-bin` 曾涉及的 AUR 供应链事件。

注意：**AUR 包版本是 5.3.x，只能证明打包配方已经跟踪 5.3 系列，不能单独证明 Linux GUI、native module、Sidecar、腾讯文档引擎等全部功能已经运行通过。** 真正确认适配还需要第二阶段做 ELF/native module 检查和 Xvfb 启动 smoke test。

## 执行检查

在 Arch Linux / GitHub Actions 的 Arch 容器终端执行：

```bash
# 进入 WorkBuddy 检查目录。
cd workbuddy

# 赋予检查脚本执行权限。
chmod +x test_workbuddy_aur.sh

# 只读检查两个 AUR WorkBuddy 配方。
./test_workbuddy_aur.sh
```

## WorkBuddy 用户配置目录

WorkBuddy 5.3.x 的主用户数据目录是：

```text
~/.workbuddy/
```

当前公开的 5.3.x 文件结构中，主要内容包括：

```text
~/.workbuddy/
├── workbuddy.db
├── settings.json
├── models.json
├── mcp.json
├── app/
│   ├── session/
│   └── window-state.json
├── projects/
├── tasks/
├── sessions/
├── memory/
├── connectors/
├── file-history/
├── artifact-index/
├── blobs/
├── traces/
└── logs/
```

因此后续即使做成 AppImage，也应保持：

- AppImage / AppDir 只放程序本体；
- 用户配置、登录态、对话、数据库继续写入 `$HOME/.workbuddy/`；
- **不要把 `~/.workbuddy/` 打进 AppImage，也不要在构建时上传到 GitHub Release。**

其中 `~/.workbuddy/` 可能包含账号会话、Connector token、自定义模型 API Key、对话历史和本地文件索引，属于用户私有数据。

## 后续打包方向

如果 AUR 当前配方确认已经跟踪 5.3.x，并且静态检查没有异常，下一阶段再决定优先参考 `workbuddy` 还是 `workbuddy-bin` 的 Linux 适配方式，然后按本仓库现有 `trae-work/` 风格整理为：

```text
workbuddy/
├── README.md
├── test_workbuddy_aur.sh
└── build_workbuddy.sh
```

正式 `build_workbuddy.sh` 应至少完成：

- 固定并校验上游版本与下载来源；
- 检查 Electron 版本；
- 检查/替换 Linux native modules；
- 检查 Sidecar / Daemon / CLI 的 Linux 可执行文件；
- 生成 AppDir；
- 使用 quick-sharun 构建 AppImage；
- 使用临时 HOME / user-data 做 Xvfb smoke test，避免触碰真实 `~/.workbuddy/`。
