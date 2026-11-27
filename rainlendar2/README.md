# Rainlendar2

本项目在仓库、构建和发布环节统一使用与上游 Linux 程序一致的 `rainlendar2` 名称。

- 项目目录：`rainlendar2/`
- 构建脚本：`rainlendar2/build_rainlendar2.sh`
- Release 产物：`rainlendar2.AppImage`
- 标准终端命令：`rainlendar2`

`rainlendar` 不作为本项目的目录名、构建脚本名、AppImage 文件名或标准终端命令。

## 版本元数据接入（2026-09-16）

- 构建脚本复用 Rainlendar 官方最新正式 Release 的 tag，并仅为统一清单去掉可选的前导 `v`，写入 `dist/version.txt`。
- workflow 使用 `SOFTWARE_KEY=rainlendar2` 接入统一 `software_versions.json`。
- 本次不改变现有 Rainlendar2 打包、GTK/IBus、铃声、Google Tasks 或 Ubuntu 兼容逻辑。

## 当前打包方式

Rainlendar2 在原生 Ubuntu 24.04 独立 Job 构建。公共入口通过认证查询最新正式 Release，匹配唯一的 Pro amd64 DEB 并校验 GitHub SHA-256，直链失败时按同一资产 ID 认证回退。打包使用 linuxdeploy 的 GTK3 插件和官方 appimagetool Type 2 runtime，版本仍取同次 Release 的标签。

AppRun 使用 GTK3 IBus 连接宿主输入法，并从程序目录读取默认铃声。运行库、铃声和同步线程兼容处理见[模板差异](./docs/template-deviations.md)。

## 运行方式

下载发布的 `rainlendar2.AppImage`，添加执行权限后运行。

```bash
./rainlendar2.AppImage
```

## 修复记录

### 2026-11-27 迁移到原生 Ubuntu 并修正 Release 查询

原构建在安装依赖后匿名查询 GitHub Release，收到 HTTP 403，尚未下载 DEB。[原构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/46025104646/job/140594450950)

改由独立 Ubuntu Job 调用认证的公共下载入口。由官方 DEB 保持原有程序布局，沿用 IBus、Pulse 铃声和 GetPath 并发兼容处理。已静态核对脚本、旧成品启动路径和调度配置。新产物的构建与实机运行待验证。
