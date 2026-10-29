# 打包分类

## 用 quick-sharun 打包的 Electron 程序

### 直接下载安装包

必须先在构建系统安装应用及运行依赖，再从 AUR 元数据、软件官方网站等核实的来源独立下载 DEB 或预编译 tar 等安装包，解包后把完整程序目录放入 `AppDir/bin`。系统安装结果用于依赖、图标、desktop 或既定版本元数据；不得用系统程序目录复制替代独立下载。

**本分类的标准模板是 Cursor 和 WorkBuddy。后续需要直接下载安装包的 quick-sharun Electron 项目，按这两个脚本的共同结构、执行顺序、通用注释、行数及空行编写。** 完整规则见 [Electron 直接下载标准](../anylinux_projects.md#直接下载安装包的标准模板)。

| 采用本分类的项目 | 构建脚本 | 当前版本来源 |
| --- | --- | --- |
| Cursor | [cursor/build_cursor.sh](../cursor/build_cursor.sh) | 官方程序内的 package.json，使用公共版本入口读取。 |
| WorkBuddy | [workbuddy/build_workbuddy.sh](../workbuddy/build_workbuddy.sh) | AUR 安装版本，使用同一个公共版本入口读取。 |
| Claude Desktop | [claude-desktop/build_claude-desktop.sh](../claude-desktop/build_claude-desktop.sh) | AUR 安装版本，使用同一个公共版本入口读取；DEB 通过公共 AUR 下载入口独立获取。 |

允许因软件不同而替换名称、包名、依赖、下载接口、路径、版本来源和必要运行参数；具体差异由对应应用的 `docs/template-deviations.md` 说明。版本读取保留在打包前原位置，版本保存统一在最终 AppImage 成功后单行调用公共脚本。当前两份模板都是 DEB，其他包格式按真实格式选用公共入口并说明差异。

用户明确暂不采用的 pkgforge-dev 专属处理，只在对应应用的 `docs/pkgforge-differences.md` 中保存原文、用途和决定，不因此改变当前分类。后续加入前必须核实官方当前是否仍有该处理，不能把旧记录直接接入构建。

### 从系统里已安装的程序取得

最终程序文件使用系统里已经安装好的那一份，保留完整程序目录及相邻资源。

- DeepSeek Harness Desktop

## 用 quick-sharun 打包的 Qt 程序

## linuxdeploy
