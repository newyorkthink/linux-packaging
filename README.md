# Linux Packaging

用于构建、重打包和修复 Linux 应用，主要生成可分发的 AppImage / RunImage。

AI 修改或提交本仓库前，先读 [AGENTS.md](./AGENTS.md)。怎么提交以其中的「GitHub 提交」为准。

## 上游 Bug

已确认属于上游的 Bug，先说明归属、依据和影响，默认保留原版并交由上游修复。只有用户知晓其上游归属后，仍针对此 Bug 明确强调要求修复并批准具体清单，才允许修改源码或加入补丁、插件、注入等规避实现。

上游 Bug 应留给上游维护者修复，本仓库默认保留上游原有实现及该 Bug。自行修改源码、打补丁或增加插件、注入等干预后，本地改动可能在上游正式修复后继续生效，与官方修复重复干预同一逻辑、覆盖官方行为，或因新版实现变化而不再兼容，进而引入新问题并增加升级和排查成本。因此，除非用户知晓上游归属及上述原因后仍明确强调要求修复，并批准具体修改清单，否则不得将这类本地修复接入或保留在正式构建、启动和发布链中。

非重大问题默认只记录；重大问题也须先说明并等待用户决定。历史参考方案不得自动恢复，以免与后续上游修复冲突。具体授权规则见 [AGENTS.md](./AGENTS.md)。

## 文档

- 人工维护：[维护者指南](./docs/maintainer-guide.md)
- AI 规范：[AGENTS.md](./AGENTS.md)
- linuxdeploy：[linuxdeploy_projects.md](./linuxdeploy_projects.md)
- Anylinux / quick-sharun：[anylinux_projects.md](./anylinux_projects.md)
- 发布机制的历史说明：[docs/release-history.md](./docs/release-history.md)
- AppImage 直接运行时自定义协议不会登记：[docs/appimage-scheme-handler.md](./docs/appimage-scheme-handler.md)
- 某个软件的状态、故障和修复：只写在该软件目录的 `README.md` 或同目录历史文件。不要写回本文件，也不要在根目录再新建待办文件。

## 手动构建

GitHub Actions → **Build AppImages** → `script_to_build` 选择 `all` 或具体脚本。`script_search` 可填应用名或脚本名，填写时优先于下拉。

标准 Arch 应用只改 `.github/appimage-apps.json`。特例仍在 `build.yml` 里单独 Job。RunImage 用 **Build RunImages**，Termux 用 **Build Termux**。

## Releases

产物在 [Releases](https://github.com/newyorkthink/linux-packaging/releases) 的 `latest`。版本写在该 Release 的 `software_versions.json`，不写进 AppImage，也不放进 Git 仓库。

官方原始安装包在 `original-package-archive`，不是 `latest`。GitHub Actions → **Archive Original Packages**，只能手动选择 `rainlendar2-pro`、`moderncsv`、`xnviewmp`、`sunshine` 或 `all`。同一软件只保留这次的文件，旧文件先删除再上传。`sunshine` 固定为 `2025.924.154138` 的 Debian Trixie `.deb` 和 `.pkg.tar.zst`，不跟官方更新版本。
