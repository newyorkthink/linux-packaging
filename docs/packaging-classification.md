# 打包分类

## 用 quick-sharun 打包的 Electron 程序

### 直接下载安装包

最终程序文件取自官方 DEB 或 tar 等安装包，解包后把完整程序目录放入 `AppDir/bin`。构建环境可以安装对应的 Arch / AUR 软件包，供依赖、图标、desktop 或既定版本元数据使用；这不改变最终程序的下载来源分类。

**本分类的标准模板是 Cursor 和 WorkBuddy。后续需要直接下载安装包的 quick-sharun Electron 项目，按这两个脚本的共同结构、执行顺序、通用注释、行数及空行编写。** 完整规则见 [Electron 直接下载标准](../anylinux_projects.md#直接下载安装包的标准模板)。

| 标准项目 | 构建脚本 | 当前版本来源 |
| --- | --- | --- |
| Cursor | [cursor/build_cursor.sh](../cursor/build_cursor.sh) | 官方程序内的 package.json，使用公共版本入口读取。 |
| WorkBuddy | [workbuddy/build_workbuddy.sh](../workbuddy/build_workbuddy.sh) | AUR 安装版本，使用同一个公共版本入口读取。 |

允许因软件不同而替换名称、包名、依赖、下载接口、路径、版本来源和必要运行参数；具体差异由对应应用的 `docs/template-deviations.md` 说明。版本读取保留在打包前原位置，版本保存统一在最终 AppImage 成功后单行调用公共脚本。当前两份模板都是 DEB，其他包格式按真实格式选用公共入口并说明差异。

### 从系统里已安装的程序取得

最终程序文件使用系统里已经安装好的那一份，保留完整程序目录及相邻资源。

- DeepSeek Harness Desktop

## 用 quick-sharun 打包的 Qt 程序

## linuxdeploy
