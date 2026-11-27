# 临时备选方案暂存目录

本目录集中暂存**尚未决定启用**的应用备选打包草稿与配套资源，与正式应用目录和 `docs/` 分开维护。

## 目录约定

- 按应用目录名建子目录，结构尽量与正式应用目录保持一致（例如 `Temporary/i3wm/` 对应 `i3wm/`），方便决定采用时直接迁入正式目录。
- 本目录内的脚本**不登记**到 `.github/appimage-apps.json` 或 `.github/workflows/build.yml`，推送变动不会触发 GitHub Actions 构建，也不影响当前 Release。
- 暂存的构建脚本保留正式位置所需的相对路径（例如 `$SCRIPT_DIR/../Common/...`），不在此目录下直接运行。
- 后续如果决定采用某项备选方案，迁入正式目录完成切换后清理对应子目录；如果确认放弃，直接删除对应子目录并更新下表。

## 当前暂存清单

| 子目录 | 对应应用 | 暂存内容与用途 | 关联说明 |
| --- | --- | --- | --- |
| [i3wm](./i3wm/README.md) | [i3wm](../i3wm/README.md) | Ubuntu 24.04 + `linuxdeploy` + 原生 `appimagetool` 备选构建脚本草稿（`build_i3wm_linuxdeploy.sh`）与官方 SVG 图标，供后续决定脱离 `quick-sharun` / `Anylinux-sharun` 运行时变动时切换使用 | [i3wm 启动子程序风险分析](../Docs/known-risks/i3wm-appimage-child-launch.md) |
