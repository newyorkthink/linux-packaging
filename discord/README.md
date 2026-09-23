# Discord AppImage

## 来源与构建

`build_discord.sh` 从 [Discord 官网](https://discord.com/download)下载 stable Linux tar.gz。2026-09-23 获取的官网归档只有约 2 MB：其中 `discord` 是调用 `updater_bootstrap` 的 Shell 入口，不是完整程序。因此构建阶段调用官方 bootstrap 下载完整 stable 程序，确认其 `Discord` 可执行文件存在后，再使用 quick-sharun 封装 `dist/discord.AppImage` 和 `dist/version.txt`。

不运行官方 `postinst.sh`，不修改宿主机 AppArmor、服务或用户配置。官方安装器下载需要访问 `updates.discord.com`；构建环境无法连接时构建会失败，不会发布只有安装器的假 AppImage。实际 CI 构建与桌面启动尚未验证。

## 2026-09-23：首次 CI 构建失败

官方安装器已成功下载完整 stable 程序，但返回的是目录名 `app-1.0.159`，原脚本误认为必须是纯版本号而退出。现在把 `app-` 前缀留在实际文件目录路径中，只从目录名提取软件版本写入 `dist/version.txt`；后续构建结果待确认。

第二轮 CI 已下载完整程序；quick-sharun 在复制图标时发现源文件和 AppDir 内目标是同一个文件而退出。图标与 desktop 现在从 AppDir 之外的官方源目录传给封装工具，下一轮结果待确认。

第三轮 CI 运行到封装主程序时提示 `Main binary is set to 'discord', but this file is NOT present`：官方下载的真实可执行文件名为 `Discord`。现已同步修正 `MAIN_BIN` 和桌面入口，后续构建待确认。

## 2026-09-23：Release 成品版本与官方下载器目录不一致

用户运行已成功构建的 Release 成品后，程序显示 `1.0.158`，并要求下载 `1.0.159`。解开同一 Release 的 `discord.AppImage`，其中 `bin/resources/build_info.json` 的实际版本确为 `1.0.158`；官方下载器返回的目录名却是 `app-1.0.159`，原脚本错误地把目录名记录成成品版本。官网当时的 `1.0.159` Linux tar.gz 和 DEB 都只有约 2 MB，需要该官方下载器另行获取完整程序；上游更新清单的 full.distro 也声明 `1.0.159`。现增加实际版本一致性检查：两者不一致时立即停止构建，禁止把旧程序作为最新版本继续发布。此时上游完整程序来源待修复，用户桌面仍会出现更新提示。

经与本仓库 `mpv`、`smplayer` 以及 quick-sharun 自带默认 `AppRun.sh` 核对，Discord 原来的手写 `AppRun.sh` 只重复指定启动程序和工作目录，没有证据表明需要保留；现交由 quick-sharun 生成默认入口。用户桌面效果尚待新成品确认。

## 2026-09-23：同名 Release 资产导致上传失败

Actions 运行 35846090462 已生成 `discord.AppImage`，但上传 `latest` 时因已有 `discord.AppImage`，`gh release upload --clobber` 连续返回 HTTP 422 `ReleaseAsset.name already exists`，重试八次仍失败。现仅在 Discord 的完整程序封装完成后，若 CI 中的 Release 已存在同名资产，先明确删除旧资产，再由现有共享步骤上传新资产；删除失败则停止发布。新一轮上传结果及桌面运行效果待确认。

## 2026-09-23：补充中文输入和中文环境

用户截图显示仍在运行 `1.0.158`，且提示 `1.0.159` 可用；上一次构建虽通过包内版本一致性检查，却在上传 Release 时失败，因此该截图不能证明新构建已替换旧资产。保留已有版本检查与同名资产上传修复，本次只调整 `build_discord.sh`：应用级安装 Arch 的 `ibus`、`fcitx5-gtk`，将两个 GTK3 输入模块明确交给 quick-sharun；生成包内 `zh_CN.UTF-8` locale 并写入 `LANG`、`LANGUAGE`、`LOCPATH`。不覆盖宿主会话选择的输入法，也不更改 Discord 官方资源或启动入口。新产物的版本、中文界面和中文输入仍待实际构建与运行确认。

## 2026-09-23：更新提示与 Release 资产核对

用户在 18:34 的启动日志中看到程序自身版本 `1.0.158`，Discord 提示 `1.0.159` 可下载。核对仓库 `main` 的构建脚本、已有 Build Discord 运行 35848533399 和 `latest` Release：该 Job 于 18:30 成功结束，现有脚本在封装前检查官方安装目录版本与 `resources/build_info.json` 的真实程序版本一致；Release 的 `discord.AppImage` 资产 ID 583540613 于 18:29 上传，SHA-256 为 `bb4aec9bf420b463efb549722c81b466d49bd6110ca69fb0796fadeeb5df3f2e`。截图中的 `1.0.158` 进程不能证明新发布资产仍为旧版，现有证据指向本地启动入口仍指向旧 AppImage。建议从本仓库 `latest` Release 取得新资产，替换原先运行的 AppImage，再启动；不应通过伪造版本或关闭更新检查掩盖旧程序。此次仅为已有日志、代码和 Release 元数据的静态核对，未下载解包新资产、未执行桌面实机验证；没有修改构建脚本，也不额外触发测试构建。
