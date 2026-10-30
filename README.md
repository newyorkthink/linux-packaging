# Linux Packaging

用于构建、重打包和修复 Linux 应用，主要生成 AppImage / RunImage，并维护 Termux 原生工具入口。

## 下载产物

打包成品统一发布在 [latest Release](https://github.com/newyorkthink/linux-packaging/releases/tag/latest)。软件版本保存在该 Release 的 `software_versions.json` 中；这份清单不提交到 Git 仓库，也不放入 AppImage。

各应用的用途、运行方法、当前状态和修复历史，查看对应应用目录的 `README.md`。已完成标准化整理的项目可从 [打包分类](./docs/packaging-classification.md) 查找；该分类不是全仓应用清单。

## 手动构建

在仓库的 **Actions** 页面选择相应工作流，点击 **Run workflow**：

| 构建类型 | 工作流 | 选择参数 |
| --- | --- | --- |
| AppImage | [Build AppImages](https://github.com/newyorkthink/linux-packaging/actions/workflows/build.yml) | `script_to_build` |
| RunImage | [Build RunImages](https://github.com/newyorkthink/linux-packaging/actions/workflows/build_runimage.yml) | `script_to_build` |
| Termux 原生工具 | [Build Termux](https://github.com/newyorkthink/linux-packaging/actions/workflows/termux.yml) | `tool` |

构建指定应用时，选择对应脚本或工具；需要全量构建时才选择 `all`。AppImage 还支持填写 `script_search`，按应用名或脚本名搜索；填写后优先于下拉选择，并且必须唯一匹配一个应用。

标准 Arch AppImage 由 [应用清单](./.github/appimage-apps.json)和 matrix 调度；构建环境或步骤不同的特例在 [build.yml](./.github/workflows/build.yml) 中保留独立 Job。各类构建继续使用各自的工作流入口。

## 官方原始包归档

官方原始安装包单独保存在 [original-package-archive Release](https://github.com/newyorkthink/linux-packaging/releases/tag/original-package-archive)，与 `latest` 中的打包成品分开。

进入 **Actions → [Archive Original Packages](https://github.com/newyorkthink/linux-packaging/actions/workflows/archive_original_packages.yml) → Run workflow**，在 `package` 中选择 `rainlendar2-pro`、`moderncsv`、`xnviewmp`、`sunshine` 或 `all`。该工作流仅手动运行。

每次只更新所选软件的归档文件，删除该软件已被替换的旧版本；已存在的同名文件保留，不重复上传。Sunshine 沿用现有固定归档版本 `2025.924.154138`，保存 Debian Trixie `.deb` 和 `.pkg.tar.zst`，不跟随官方新版更新。

## 文档导航

| 需要了解的内容 | 入口 |
| --- | --- |
| 全部文档与专项问题 | [文档索引](./docs/README.md) |
| 人工维护流程 | [维护者指南](./docs/maintainer-guide.md) |
| AI 操作、修改授权与提交规则 | [AGENTS.md](./AGENTS.md) |
| 已标准化项目与打包分类 | [打包分类](./docs/packaging-classification.md) |
| AppImage 对应上游仓库与构建代码 | [上游打包参考索引](./docs/upstream-packaging-index.md) |
| Anylinux / quick-sharun 规范 | [anylinux_projects.md](./anylinux_projects.md) |
| linuxdeploy 规范 | [linuxdeploy_projects.md](./linuxdeploy_projects.md) |
| AppImage 自定义协议登记 | [协议入口说明](./docs/appimage-scheme-handler.md) |
| 发布机制的历史说明 | [Release 发布历史](./docs/release-history.md) |

## 维护约定

AI 处理本仓库前必须完整阅读 [AGENTS.md](./AGENTS.md)，修改授权和提交流程以其中的规则为准。

应用的状态、故障、修复和待办只记录在该应用目录的 `README.md`、已有历史文件或 `docs/` 中。顶层 README 只保留仓库导航，不保存应用故障记录，也不在根目录另建待办文件。

### 上游 Bug 的处理

已确认属于上游的 Bug，先说明归属、依据和影响，默认保留上游原版及该 Bug，交由上游修复。自行添加补丁、插件或注入可能与后续官方修复重复、覆盖上游行为，或因新版变化而失效，增加排查和维护成本。

只有用户了解上游归属及上述风险后，仍针对此 Bug 明确强调要求本仓库修复，并批准具体修改清单，才允许接入相应处理。非重大问题默认只记录，重大问题同样先说明并等待决定；历史参考方案不得自动恢复，以免与上游修复冲突。
