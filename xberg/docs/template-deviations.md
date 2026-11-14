# Xberg 预编译归档打包说明与模板差异

## 来源与分类

采用 [xberg-io/xberg](https://github.com/xberg-io/xberg) 官方 GNU x86_64 预编译归档，保持主程序及相邻共享库的完整目录，归入 [quick-sharun 官方预编译归档命令行工具](../../docs/packaging-classification.md#用-quick-sharun-打包的官方预编译归档命令行工具) 分类。构建脚本复用现有 quick-sharun 公共入口，应用专属目录和资源准备按本文维护，不新增标准模板。

在 pkgforge-dev 中按 Xberg 和 Kreuzberg 名称分别查找，未找到对应打包仓库；上游索引仅记录这个查找结果，不复制其他应用的 hooks、源码构建或专属设置。

## 官方依据

本次核对的上游源码提交为 `f319f78c368a3e017f8e062d74b14896c080cd07`，品牌资源提交为 `4f164c20282374cb1fcdec578e300370c77014b9`。

[官方发布流程 v1.4.0](https://github.com/xberg-io/xberg/blob/f319f78c368a3e017f8e062d74b14896c080cd07/.github/workflows/publish.yaml) 的 GNU CLI 阶段复制主程序及两份许可证，调用 [vendor-native-closure.sh](https://github.com/xberg-io/xberg/blob/f319f78c368a3e017f8e062d74b14896c080cd07/scripts/ci/vendor-native-closure.sh) 将非基础运行库放在程序旁并设置 `$ORIGIN`。官方说明 GNU 闭包保留 libc、加载器、C++ 运行时及 OpenSSL 由宿主提供；本流程使用 Arch 基础包准备这些运行时，并由 quick-sharun 收集。

这里的版本链接仅定位所读依据，构建资产仍由公共入口动态选择。没有复制或执行官方的源码构建和测试流程。

AUR 公开来源检索未查到 Xberg / Kreuzberg 对应包，本流程不以 AUR 配方作为二进制来源；安装阶段与最终入包均使用已核实的官方 GNU 资产。

## 公共入口与专属处理

| 阶段 | 处理与依据 |
| --- | --- |
| 工具和依赖 | 调用 `common/arch/install_packages.sh --base`，不加入无依据的 Qt、GTK、Python 或 OCR 配置。 |
| 工作区 | 公共入口只重建本应用的 `AppDir/work/dist`。 |
| 系统安装 | 公共下载和解包入口准备完整官方归档；应用专属目录复制到隔离构建系统的 `/opt/xberg`，提供系统命令入口。 |
| 最终来源 | 第二次独立下载、校验和解包得到最终程序，整体复制到 `AppDir/bin`，不从系统安装目录复制。 |
| 依赖收集 | `quick-sharun ./AppDir/bin/*` 明确以当前完整官方目录作为输入；不全盘搜索或拼接系统扫描清单。 |
| 元数据 | `MAIN_BIN=xberg`、自备 CLI desktop 和 `patched/xberg.svg` 中的官方 SVG。命令行参数由工具生成的 AppRun 传给 Xberg。 |
| 许可证 | 保留官方 `LICENSE`、`THIRD_PARTY_LICENSES.md` 和 `patched/branding-LICENSE` 中的品牌资源 MIT 许可证。 |
| 封装和版本 | 使用原有 `quick-sharun --make-appimage` 与公共版本保存入口，最终文件名为 `xberg.AppImage`。 |

## 图标来源

图标和品牌许可证分别原样保存在 [`patched/xberg.svg`](../patched/xberg.svg) 与 [`patched/branding-LICENSE`](../patched/branding-LICENSE)，构建时按原顺序复制到 `work`，后续图标设置和许可证入包路径保持不变。

SVG 正文来自 [xberg-io/assets 的官方单色标志](https://github.com/xberg-io/assets/blob/4f164c20282374cb1fcdec578e300370c77014b9/logo/symbol-mono-black.svg)，图标与其内嵌图像保持原样。其 [MIT 许可证](https://github.com/xberg-io/assets/blob/4f164c20282374cb1fcdec578e300370c77014b9/LICENSE) 随包保留；遵循[品牌使用说明](https://github.com/xberg-io/assets/blob/4f164c20282374cb1fcdec578e300370c77014b9/logo_usage_rules.md)，不拉伸、旋转、重绘或改色。

## 运行记录

官方 GNU CLI 的 DOC 提取通过结果统一见 [README 实机验证](../README.md#实机验证)。
