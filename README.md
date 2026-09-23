# Linux Packaging

用于构建、重打包和修复 Linux 应用，主要生成可分发的 AppImage / RunImage。

AI 修改或提交本仓库前，先读 [AGENTS.md](./AGENTS.md)。怎么提交以其中的「GitHub 提交」为准。

## 文档

- 人工维护：[维护者指南](./docs/maintainer-guide.md)
- AI 规范：[AGENTS.md](./AGENTS.md)
- linuxdeploy：[linuxdeploy_projects.md](./linuxdeploy_projects.md)
- Anylinux / quick-sharun：[anylinux_projects.md](./anylinux_projects.md)
- 发布机制的历史说明：[docs/release-history.md](./docs/release-history.md)
- 某个软件的状态、故障和修复：只写在该软件目录的 `README.md` 或同目录历史文件。不要写回本文件，也不要在根目录再新建待办文件。

## 手动构建

GitHub Actions → **Build AppImages** → `script_to_build` 选择 `all` 或具体脚本。`script_search` 可填应用名或脚本名，填写时优先于下拉。

标准 Arch 应用只改 `.github/appimage-apps.json`。特例仍在 `build.yml` 里单独 Job。RunImage 用 **Build RunImages**，Termux 用 **Build Termux**。

## Releases

产物在 [Releases](https://github.com/newyorkthink/linux-packaging/releases) 的 `latest`。版本写在该 Release 的 `software_versions.json`，不写进 AppImage，也不放进 Git 仓库。
