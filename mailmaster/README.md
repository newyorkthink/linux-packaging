# MailMaster AppImage

## 用途与产物

本目录使用当前 AUR `mailmaster` 配方提供的应用文件，通过 quick-sharun 重新封装为 `mailmaster.AppImage`。正式构建入口为 `.github/workflows/build.yml` 的 `Build MailMaster` Job。

## 打包方式

通过公共 Arch 入口按 AUR 配方安装应用和依赖，再从 AUR 当前来源单独下载、校验和解包主 DEB。将完整的 `opt/mailmaster` 内容放入 `AppDir/bin`，补齐 AUR 提供的兼容库和许可证，保持 Qt 5 / CEF 资源的相对布局。

quick-sharun 生成启动入口。包内 `.env` 设置 Qt 插件路径、工作目录和中文 locale，启动 hook 保留主题隔离、输入法默认值和 CEF 参数。Qt 5 IBus 模块来自应用，Qt 5 Fcitx5 模块来自 Arch 的 `fcitx5-qt`。

- [模板差异与来源](./docs/template-deviations.md)
- [固定配置依据](./docs/hardcoded.md)
- [打包分类](../docs/packaging-classification.md#用-quick-sharun-打包的-qt-程序)

## 运行

下载 Release 中的 `mailmaster.AppImage` 后赋予执行权限并直接运行：

```bash
./mailmaster.AppImage
```

## 版本元数据

构建版本取自本次下载的 DEB。公共入口核对 DEB 版本与 AUR `pkgver` 一致，封装成功后写入 `mailmaster/dist/version.txt`。workflow 上传为 `software-version-mailmaster` 并增量写入 `latest/software_versions.json`。

## 维护说明

- 从 AUR 当前 `.SRCINFO` 读取下载地址、版本和摘要。`mailmaster-{version}.deb` 是主包的缓存文件名规则，AUR 更换镜像时会自动跟随。若配方改变命名规则，需要重新核对选择参数。
- 保持现有程序目录、Qt / CEF 路径和 quick-sharun 兼容逻辑。
- 版本元数据与资产 SHA-256 分离使用。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 增加标准 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=mailmaster` 与统一版本清单。

### 2026-11-03：按 quick-sharun 标准整理 AUR 构建

- 故障：[Build MailMaster 日志](https://github.com/newyorkthink/linux-packaging/actions/runs/41263573517/job/124733830878)显示 GitHub Actions 连接山东大学镜像超时，主 DEB 下载失败。
- 处理：构建入口接入公共安装、下载、解包、版本读取和保存脚本。公共多来源选择能力见 [156618d](https://github.com/newyorkthink/linux-packaging/commit/156618d8c5ceab8d0f97c3c9a5c76deca94dcc1f)。主包按 AUR 原摘要校验，Qt 5 / CEF 扁平布局和兼容库继续保留。
- 已核对：从 AUR 所列镜像下载并解包真实 DEB，SHA-256、版本与目录布局匹配。核对了两种 Qt 5 输入法模块所需的 Qt 符号、Bash 语法及 hook 参数传递。
- 待验证：GitHub Actions 的镜像连通性、完整 AppImage 构建、启动及实机中文输入。当前构建使用 AUR 配方给出的主包地址。
