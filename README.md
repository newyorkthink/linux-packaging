# Linux Packaging

用于构建、重打包和修复 Linux 应用，主要生成可分发的 AppImage / RunImage。

> [!IMPORTANT]
> **AI coding agents 在读取、修改或提交本仓库前，必须先完整阅读 [AGENTS.md](./AGENTS.md)。**  
> 本仓库关于修改范围、安全要求、打包方式、GitHub Actions、Release 和验证流程的详细规范，均以 `AGENTS.md` 为准。

## 仓库说明

- 每个应用原则上使用独立目录维护构建脚本和相关文件。
- 正式 AppImage 构建统一由 `.github/workflows/build.yml` 管理。
- 已验证正常的现有构建方案视为稳定基线，修改时应遵循最小变更原则。
- 优先使用上游官方程序、资源和发布包，只处理 Linux 打包、依赖、启动及兼容性问题。

## Releases

构建产物通常发布到仓库的 [Releases](https://github.com/newyorkthink/linux-packaging/releases)，持续更新版本使用 `latest` Release。

> 本 README 仅作为仓库入口说明；AI 操作本仓库时请以 [AGENTS.md](./AGENTS.md) 为完整规范。
