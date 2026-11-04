# 标准模板与生成记录

## 本次采用的模板

- 程序技术栈仍为 Electron / Chromium。
- 本次使用仓库现有的 [`templates/quick-sharun/qt-deb.sh`](../../templates/quick-sharun/qt-deb.sh) 提供的 AUR DEB 来源流程。该模板正文没有 Qt 专属安装或导出命令；依赖参数按本程序填写为 `fcitx5-gtk`。
- [正式 build](../build_adspower-global.sh) 是生成器原始输出，只替换登记参数，未手工增删模板正文、注释、命令或空行。模板未包含的 `DEPLOY_GTK`、`URUNTIME_PRELOAD`、`STRACE_BINARY` 和 `STRACE_FLAGS` 均未追加到本稿。

## 生成来源

| 项目 | 内容 |
| --- | --- |
| 生成工作流 | `.github/workflows/generate-build-script.yml` |
| 生成任务 | [41879128128，运行次数 1](https://github.com/newyorkthink/linux-packaging/actions/runs/41879128128) |
| 源码提交 | `7a99949516d90aecd942eec744dba5cb90004ff9` |
| 模板 | `quick-sharun/qt-deb.sh` |
| 输出路径 | `adspower-global/build_adspower-global.sh` |
| 输出 SHA-256 | `9af6631ecfbb6c77041fe5ae2d7b0096f99b3b495110d2b44cfb29e1d4754610` |
| 已执行检查 | 生成器的参数、路径和 Bash 语法检查；生成稿与模板固定内容逐字核对 |

生成任务仅输出脚本，不执行依赖安装、DEB 下载或应用打包。公共请求文件已恢复为空任务结构。

## 来源与版本

- AUR 包为 `adspower-global-bin`，DEB 源文件名模板为 `AdsPower-Global-{version}-x64.deb`。
- 公共入口按文件名模板选择 `.SRCINFO` 中的对应来源和摘要，支持本配方使用的通用 `source` 及 `文件名::HTTPS URL` 写法。
- 系统安装准备运行依赖、图标和 desktop；最终程序文件来自第二阶段独立下载、校验和解包的官方 DEB。
- 版本读取同次下载产生的 `work/source-version.txt`，跟随 AUR 配方，不写死某次查询得到的版本。

## 旧版保留范围

[旧版备份](../build_adspower-global_old.sh) 原样保留旧下载解析、ICU 输入检查、desktop 调整、图标选择以及 runtime / strace 配置，仅供查阅。

备份未加入应用清单或手动构建选项。现有工作流在触发路径中忽略 `build_*_old.sh`，Plan 也过滤应用目录内未登记的 `build_*.sh`；正式入口继续使用 `build_adspower-global.sh`。

后续出现实际报错或明确运行反馈时，只恢复与该问题直接对应且仍有必要的最小处理，并通过统一生成机制落地。既有实机通过记录与故障历史继续保留在 [README](../README.md)。
