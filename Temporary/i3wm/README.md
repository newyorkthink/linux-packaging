# i3wm 的 linuxdeploy + 原生 appimagetool 备选方案

本目录暂存 `i3wm` 切换至 **Ubuntu 24.04 原生 runner + `linuxdeploy` + 官方 `appimagetool`（SquashFS Type 2）** 的完整备选草稿与资源。当前正式构建仍保留根目录 [i3wm/build_i3wm.sh](../../i3wm/build_i3wm.sh)（Arch + `quick-sharun` 路线），本目录文件不参与任何 GitHub Actions 构建或发布。

## 为什么暂存这份方案

2026-11-27 的排查确认：即使 `i3wm/build_i3wm.sh` 已按标准模板整理、包内 `i3` 本体（`4.25.1`）与全部 12 个二进制逐字节未变，上游 `pkgforge-dev/Anylinux-sharun` 运行时从 `3.2.2` 升级到 `3.11.0` 后，仍改变了 `i3` 通过 `execl` 启动桌面子进程时的环境变量恢复行为，导致部分外部程序出现闪退或崩溃（完整证据与分析见 [从 i3wm AppImage 启动别的程序](../../Docs/known-risks/i3wm-appimage-child-launch.md)）。

本备选方案用于提供一条**不依赖 `Anylinux-sharun` / `anylinux.so` 运行时拦截层**的退路：

- **构建底稿**：以固定模板 [linuxdeploy-cli-apt.sh](../../Templates/appimage/linuxdeploy-cli-apt.sh) 为底稿，运行于 GitHub Actions `ubuntu-24.04` 原生 runner，不使用 Docker。
- **零库路径污染设计**：`linuxdeploy` 自动扫描 `AppDir/usr/bin/` 全部 ELF，部署共享库到 `AppDir/usr/lib/` 并写入 `$ORIGIN/../lib` 与 `$ORIGIN` RPATH；根 `AppRun` **不导出 `LD_LIBRARY_PATH`、不注入 `LD_PRELOAD`、不改写 `XDG_DATA_DIRS` 或 `XDG_CACHE_HOME`**，并在 `exec` 前显式 `unset APPDIR APPIMAGE ARGV0 OWD`，避免影响桌面子进程或嵌套 AppImage。
- **工具集合与边界**：提取 Ubuntu 24.04 仓库的 `i3-wm`，从 `i3status`、`suckless-tools`、`xss-lock` 按白名单复制 6 个配套命令，严格保持 20 个内置入口并显式校验排除 `slock` 与 `i3lock`；Perl 辅助脚本继续使用宿主 Perl。
- **默认配置与图标**：将默认 `/etc/i3/` 与 `/etc/i3status.conf` 同步复制到 `AppDir/etc/xdg/`，通过 `XDG_CONFIG_DIRS` 末尾追加提供回退（无需 `PATH_MAPPING`）；采用取自官方 `i3/i3` 仓库的 [patches/i3.svg](./patches/i3.svg) 避开原 `logo-30.png`（`30×29` 非正方形）被 `linuxdeploy` 拒绝的问题，并配合 `librsvg2-bin` 由公共封装脚本生成 256×256 根 PNG。

## 与现网 Arch `quick-sharun` 路线的差异

| 对比项 | 当前正式版（`i3wm/build_i3wm.sh`） | 本备选方案（`build_i3wm_linuxdeploy.sh`） |
| --- | --- | --- |
| 构建环境 | Arch Linux 容器（`quick-sharun` + DwarFS） | `ubuntu-24.04` 原生 runner（`linuxdeploy` + SquashFS Type 2，无 Docker） |
| `i3-wm` 版本 | Arch 当前稳定版（如 `4.25.1`） | Ubuntu 24.04 LTS 仓库版（`4.23`） |
| 运行时拦截层 | 包含 `anylinux.so` / `path-mapping.so`，受上游更新影响 | 无 `anylinux.so` / `LD_PRELOAD`，ELF 通过 RPATH 查找随包运行库 |
| 配置兼容性 | 支持 `4.24`–`4.25` 新增语法 | `gaps` 已在 `4.22` 合并；仅不支持 `4.24`–`4.25` 新增配置项（如 `popup_during_fullscreen all`、`swap_modifier`） |
| Release 资产与版本键 | `i3.AppImage` / `i3` | 保持不变（`i3.AppImage` / `i3`） |

## 决定切换前的检查项

将来准备评估或启用本方案时，先完成以下核对，再向用户列出修改清单并取得明确同意：

1. **先查上游版本变化**：核对上游 `pkgforge-dev/Anylinux-sharun`（`anylinux.so`、`AppRun.lib`、`path-mapping.so`）与 `pkgforge-dev/Anylinux-AppImages`（`quick-sharun`）的最新版本及变更日志，确认是否已修复相关问题或引入新变化，再决定是继续保留旧版、重测 `quick-sharun` 新版，还是正式切换到本方案。
2. **核对 Ubuntu 仓库现状**：如果 GitHub Actions runner 升级到更新版 Ubuntu（如 26.04），或需要更高版本 `i3`，先核对目标 Ubuntu 仓库中 `i3-wm` 的实际版本，以及 `suckless-tools` 中 `dmenu` / `slock` 的文件布局是否变化。
3. **注意 `XDG_CACHE_HOME` 实机排查点**：本方案去掉了 `anylinux.so` 拦截层和 `LD_LIBRARY_PATH` 污染，但它与正常宿主环境一样使用默认的 `XDG_CACHE_HOME`（`~/.cache`），**不会**像旧版 `Anylinux-sharun 3.2.2` 那样指向 `~/.cache/AppImage-Cache`。切换后若个别外部程序仍出现崩溃，应一并排查其自身在 `~/.cache` 下的缓存状态，避免误判为 `linuxdeploy` 打包失败。

## 后续切换命名规则与改动范围

如果后续决定正式切换到 `linuxdeploy` 路线，按以下命名与接线约定执行（须先按仓库 `AGENTS.md` 逐次授权规则获批）：

1. **脚本命名区分**：
   - 将现有 `quick-sharun` / AnyLinux 版的 `i3wm/build_i3wm.sh` 更名为 `build_i3wm_anylinux.sh`（若不再参与正式构建，可移至 `Temporary/i3wm/` 或保留为未登记脚本；按 `.github/scripts/plan_appimage_jobs.py` 规则，未登记到清单的 `build_*.sh` 不会触发正式构建）。
   - 将本目录的 [build_i3wm_linuxdeploy.sh](./build_i3wm_linuxdeploy.sh) 与 [patches/i3.svg](./patches/i3.svg) 分别移入 `i3wm/build_i3wm_linuxdeploy.sh`（Git 模式 `100755`）与 `i3wm/patches/i3.svg`（Git 模式 `100644`）。
2. **同步修改的正式文件**：
   - `.github/appimage-apps.json`：将 `i3wm` 的 `kind` 从 `standard` 改为 `special`，`script` 改为 `i3wm/build_i3wm_linuxdeploy.sh`（保持 `artifact_dir: "i3wm/dist"`、`release_name: "i3.AppImage"`、`software_key: "i3"` 不变）。
   - `.github/workflows/build.yml`：将 `workflow_dispatch.inputs.script_to_build.options` 中的 `i3wm/build_i3wm.sh` 同步改为 `i3wm/build_i3wm_linuxdeploy.sh`，并新增独立 Job `build_i3wm`（参考下方 YAML 片段）。
   - `.github/scripts/plan_appimage_jobs.py`：在 `standalone_publish_jobs` 集合中加入 `"i3wm"`。
   - `i3wm/README.md`、`i3wm/docs/template-deviations.md`、`Docs/packaging-classification.md`、`Docs/upstream-packaging-index.md`、`linuxdeploy_projects.md`、`Docs/packaging-export-registry.md`：同步更新脚本路径、打包路线、差异说明与 `export` 登记位置（`PATH_MAPPING` 移除 `i3wm`，`XDG_CONFIG_DIRS` 与构建期 `LD_LIBRARY_PATH` 补充 `i3wm`，不新增 `export` 变量）。
3. **切换并实机验收重点**：
   - 确认 `i3 --version`、`i3bar`、`i3status`、`i3-msg`、`i3-input`、`dmenu`、`xss-lock` 及原地重启正常；
   - 重点验证从 `i3` 直接启动的外部图形工具、终端客户端与嵌套 AppImage 是否全部正常。
4. **清理暂存**：切换验收完成后清理 `Temporary/i3wm/` 并同步更新 [Temporary/README.md](../README.md)。

### 参考配置：`build.yml` 中的独立 `build_i3wm` Job

```yaml
  build_i3wm:
    name: Build i3wm
    needs: plan
    if: fromJSON(needs.plan.outputs.builds).i3wm == 'true'
    concurrency:
      group: build-appimage-i3.AppImage
      queue: max
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
      - name: Build i3wm AppImage
        env:
          GH_TOKEN: ${{ github.token }}
        shell: bash
        run: |
          set -Eeuo pipefail
          chmod +x i3wm/build_i3wm_linuxdeploy.sh
          ./i3wm/build_i3wm_linuxdeploy.sh
      - name: Upload software version metadata
        uses: actions/upload-artifact@v4
        with:
          name: software-version-i3
          path: i3wm/dist/version.txt
          if-no-files-found: error
          retention-days: 1
      - name: Publish to Latest Release
        env:
          GH_TOKEN: ${{ github.token }}
        shell: bash
        run: |
          set -Eeuo pipefail
          "$GITHUB_WORKSPACE/Common/github/publish_release_asset.sh" "$GITHUB_REPOSITORY" i3wm/dist/i3.AppImage
      - name: Publish software version immediately
        uses: ./.github/actions/publish-software-versions
        with:
          software_key: 'i3'
          version_file: 'i3wm/dist/version.txt'
          asset_name: 'i3.AppImage'
          artifact_dir: 'i3wm/dist'
          github_token: ${{ github.token }}
```
