# TraeWork Linux 实验移植

这个目录只用于测试 TraeWork 桌面版在 Linux x86_64 上的可行性，不属于仓库现有稳定 AppImage 构建。

## 当前实验方案

- TraeWork 产品层：使用 Windows x64 正式版 `0.1.54 / 2.3.76123` 的 `resources/app`。
- Linux 运行时：沿用仓库 `trae/` 已验证的 AUR `trae` Linux x64 Electron 运行时获取方式。
- 原生组件：将 Linux TraeCode 中对应的 ELF、`.so`、`.node` 覆盖或补入 TraeWork 目录。
- 兼容重点：单独补入旧社区移植明确涉及的 `libai_agent.so`、`libckg.so` 和 `native-keymap`。
- 产物：只生成 `trae-work.AppImage` 和诊断日志，不发布到 `latest` Release。

## 独立 GitHub Actions

测试 workflow：`.github/workflows/trae-work-test.yml`

它只在以下情况运行：

1. `trae-work/**` 发生变化并推送到 `main`；
2. 测试 workflow 自身发生变化；
3. 手动 `workflow_dispatch`。

没有 `schedule`，没有 `contents: write`，不会调用主 `.github/workflows/build.yml` 的发布逻辑，也不会修改现有正常 AppImage Release。

## 判断标准

旧版 macOS → Linux 社区移植的核心失败点是 Linux `libai_agent.so` 缺少 TraeWork/原 SOLO 使用的 `lite` 服务。当前测试会：

- 对比 Windows TraeWork 与 Linux TraeCode 的 ai-agent 相关字符串；
- 在 Xvfb 中启动 AppImage 30 秒；
- 检查日志是否再次出现 `unknown service: lite` / `solo-lite`；
- 把 `port-report.txt` 和 `smoke-test.log` 与 AppImage 一起保存为 7 天 Artifact。

这只能证明“能否构建并完成基础启动”；本地项目选择、登录、Agent 执行等仍需在真实 Linux 桌面环境继续验证。
