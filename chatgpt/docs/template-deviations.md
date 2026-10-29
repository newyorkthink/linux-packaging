# ChatGPT 模板差异

核对日期：2026-10-30。通用骨架沿用 [Electron 直接下载标准](../../anylinux_projects.md#直接下载安装包的标准模板)，基础模板 69 行，加 Qt 清理 3 行和两个 hook 10 行，共 82 行。

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 先安装再下载 | 采用标准两阶段 | [依赖安装](../build_chatgpt.sh#L11-L13)；[三行下载](../build_chatgpt.sh#L20-L22) | 安装 chatgpt-desktop 后，从当前 AUR 元数据指向的 OpenAI 官方地址独立取得 DEB，并校验 SHA-256；不复制系统程序目录。 |
| 程序与桌面资源 | 采用标准步骤 | [完整目录复制](../build_chatgpt.sh#L28)；[系统图标与 desktop](../build_chatgpt.sh#L42-L44) | 完整复制 usr/lib/chatgpt；ICON、DESKTOP 直接赋值，不枚举或另建桌面资源。 |
| 版本来源 | 使用公共 JSON 读取 | [版本读取](../build_chatgpt.sh#L53) | 公共 package-json 来源按根字段 version 读取 linux-package-metadata.json，与旧脚本已核实的官方元数据结构一致。 |
| Qt shim | 采用官方原命令 | [删除命令](../build_chatgpt.sh#L31) | 全目录收集会把 shim 作为输入并处理 Qt 依赖；本稿采用官方删除方案。只删除打包副本，Plasma 主题效果没有本次实测。 |
| 依赖收集 | 采用官方原命令 | [完整目录收集](../build_chatgpt.sh#L56) | 用 quick-sharun 默认检测和部署，不保留旧 ELF 数组、手工库路径或强制关闭自动部署的设置。 |
| 中文环境 | 采用标准步骤 | [包内 locale](../build_chatgpt.sh#L59-L66) | GTK 输入模块由工具收集，中文 locale 及四项环境变量按模板生成。 |
| 宿主 bwrap | 保留已有修复 | [PATH hook](../build_chatgpt.sh#L69-L71) | 保留既有 PATH 原文，宿主 /usr/bin、/bin 在前，避免 Codex 调用包内 bwrap 包装器。 |
| Electron 启动兼容 | 保留已有参数 | [参数 hook](../build_chatgpt.sh#L74-L76) | 保留 --no-sandbox、--disable-setuid-sandbox，不等于禁用 Codex 命令沙箱。 |
| 旧自检及目录包装 | 不采用 | 未启用。 | 删除旧下载解析、ELF 筛选、额外开关、产物解包与图形/沙盒自测；不把历史 CI 通过写成新稿的验证结果。 |

官方原文及取舍见 [pkgforge 记录](pkgforge-differences.md)，固定值见 [配置依据](hardcoded.md)，完整历史见 [README](../README.md)。本次复用已完成的语法检查，不重复测试；未进行新的完整构建或实机运行。
