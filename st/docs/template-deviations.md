# st 专属打包差异

## 采用专用流程的原因

st 从 `siduck/st` 默认分支下载当前提交的源码，生成构建所需的 `config.h`，再通过 `make` 安装到构建环境。现有 `templates/quick-sharun/arch-native.sh` 面向已安装的系统原生程序，不提供源码下载、字体配置生成和源码编译阶段，因此本项目保留专用打包流程，不新增标准模板。

## 通用阶段

- 使用 `common/arch/install_packages.sh` 安装基础工具、编译依赖及运行依赖。
- 使用 `common/build/prepare_x86_64_workspace.sh` 清理并准备 `AppDir`、`work` 和 `dist`。
- 通过 `common/github/download_default_branch_source.sh` 下载当前源码，再用 `common/archive/extract_archive.sh` 解包。
- 使用 `quick-sharun` 收集程序并封装 AppImage；通过 `common/build/save_appimage_version.sh` 保存最终版本，继续附加当前源码提交的 12 位短 SHA。

## 程序专属处理

- 继续读取 `font-config.sh`，由 `patches/apply_font_config.py` 按原有规则生成 `config.h`，不修改上游 `config.def.h`；`font` 与 `font2` 字段的替换数量检查保留在补丁中，用于防止上游字段变化造成错误配置。
- 在字体补丁运行后读取 `patches/theme-config.sh`，由 `patches/apply_theme_config.py` 修改生成的 `config.h` 中的 ANSI 16 色、光标、前景、背景及透明度；保留字体逻辑与其他构建阶段。主题参数专属于 st，不加入公共打包脚本。
- 保留 `make -C "$SOURCE_DIR" PREFIX=/usr install` 源码编译安装流程，不改为安装另一个 st 软件包。
- 保留 `MAIN_BIN=st`、`st-copyout`、`st-urlhandler`、`st-256color` 的 terminfo 和许可证封装，不改变运行入口。
- 删除原构建脚本里重复的 `test` 存在性检查；输入缺失由后续实际构建命令报错，版本解析仍要求取得非空结果。

## 划选自动复制补丁

鼠标划选后自动复制到系统剪贴板采用 [suckless 官方 one clipboard 补丁](https://st.suckless.org/patches/clipboard/)；[原始补丁](https://st.suckless.org/patches/clipboard/st-clipboard-0.8.3.diff)保存在 `patches/clipboard.patch`，补丁正文原样保留。官方说明其用途是在选中文本时设置 `CLIPBOARD`，便于在终端与浏览器之间复制。

本次核对的 [siduck/st 源码](https://github.com/siduck/st/blob/73a289ad83114e6fc6ac6d7d510f0b9c7a908158/x.c#L682)中，`setsel()` 原本只设置 `PRIMARY`；已有 `clipcopy()` 负责复制选区并取得 `CLIPBOARD` 所有权。补丁仅在 `setsel()` 末尾增加一行 `clipcopy(NULL);`，继续使用上游已有实现。

`build_st.sh` 在字体和主题处理完成后、`make` 编译安装前应用补丁；构建基础包已包含 `patch`，不增加依赖、环境变量或运行时辅助程序。保留字体、主题、原有快捷键及其余打包步骤。补丁使用 `--batch --forward --fuzz=0`，上游上下文变化或已应用时明确退出，不反向修改源码。

## 已有实机记录

本次通过记录与构建依据见 [README 的实机验证章节](../README.md#实机验证)；既有打开、输入及拼音候选框的确认记录继续保留在同一文档中。
