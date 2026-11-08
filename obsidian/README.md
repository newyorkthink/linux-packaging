# Obsidian AppImage

## 用途与产物

本目录从 Obsidian 官方正式 Release 中选择带有 Linux AMD64 DEB 资产的桌面版本，经公共下载入口校验后封装为 `obsidian.AppImage`。

## 技术栈与打包方式

Obsidian 为 Electron 桌面应用。构建时先安装 AUR `obsidian-bin` 及运行依赖，再独立下载官方 AMD64 DEB，将完整的 `opt/Obsidian` 程序目录复制到 `AppDir/bin`。quick-sharun 收集 GTK3、X11、NSS、IBus、OpenGL、Vulkan 和 PipeWire 运行组件，并生成 AppImage 与包内中文环境。

## 版本元数据

下载入口将同次官方 Release 的版本保存到 `work/source-version.txt`；构建脚本读取该版本，AppImage 成功生成后由公共入口写入 `dist/version.txt`。现有 workflow 继续使用 `SOFTWARE_KEY=obsidian` 接入统一版本清单。

## 运行

```bash
./obsidian.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加统一版本输出与发布映射，不改变现有 Obsidian 上游选择、Electron 依赖或输入法逻辑。


### 2026-11-08：正式使用标准化 DEB 构建流程

`build_obsidian.sh` 已使用标准化版本替换原实现；原有 tar.gz 构建方案可从 Git 提交历史查阅。新增源码取舍和固定配置说明，原构建清单中的脚本路径、发布名称及软件版本键保持不变。

## 上游参考与应用差异

当前脚本使用现有 [Electron GitHub Release DEB 模板](../templates/quick-sharun/electron-github-deb.sh) 的标准阶段，包含本应用既有的 OpenGL、Vulkan、PipeWire 和 NSS、hostname、GTK3 IBus 扫描配置。没有引入 pkgforge-dev 的自更新、命名空间 hook 或构建后测试步骤。

固定路径和包来源见 [固定配置说明](./docs/hardcoded.md)；专属依赖、配置和扫描目标见 [模板差异](./docs/template-deviations.md)；[上游实现及取舍](./docs/pkgforge-differences.md) 记录对应源码和未启用处理。
