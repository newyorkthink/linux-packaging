# DeepSeek Harness AppImage

将 DeepSeek 官方 [`deepseek-ai/deepseek-harness`](https://github.com/deepseek-ai/deepseek-harness) 的 npm 发行包 `@deepseek-ai/dsh` 封装为自包含 Linux x86_64 AppImage。

## 定位

- 核心运行时：仅使用 DeepSeek 官方 `@deepseek-ai/dsh`。
- 不包含 MichengAI / sdkwork-ai 等第三方 Desktop 外壳或社区插件。
- Node.js 一并封装进 AppImage。
- **npm 只在 GitHub Actions 构建阶段使用，最终用户不需要安装 Node、npm 或 pnpm。**
- 默认启动官方本地 Web UI；不是 `chat.deepseek.com` 在线网页。

## 使用

```bash
chmod +x deepseek-harness.AppImage
./deepseek-harness.AppImage
```

无参数等价于运行官方：

```bash
dsh web
```

也可以直接透传官方 DSH CLI 参数：

```bash
./deepseek-harness.AppImage --help
./deepseek-harness.AppImage web --no-open
```

DSH 的配置、会话和凭据继续保存在用户自己的 `~/.dsh`（或自定义 `DSH_HOME`）中，不写进 AppImage，因此替换新版 AppImage 不会清空用户数据。

## 构建

构建脚本：

```text
build_deepseek-harness.sh
```

脚本会：

1. 从 npm 查询 DeepSeek 官方 `@deepseek-ai/dsh` 最新版本；可通过 `DSH_VERSION` 手动固定版本。
2. 在 AppDir 内安装官方 DSH 运行时及其正式依赖。
3. 使用仓库现有 AnyLinux / quick-sharun 方案封装 Node 和所需 Linux 动态库。
4. 使用 DeepSeek Harness 官方仓库的 `favicon.svg`。
5. 生成 `dist/deepseek-harness.AppImage`，执行 `--help` 烟测并生成 SHA256。

该项目已接入仓库统一 `.github/workflows/build.yml`：支持目录变更自动构建、手动单独选择和每日统一构建，并发布到 `latest` Release。
