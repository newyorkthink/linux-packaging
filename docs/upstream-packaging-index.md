# 上游打包参考索引

本页用于查找当前 AppImage 项目对应的 pkgforge-dev 打包仓库和构建代码，防止调整 `build_*.sh` 时遗漏上游参考。这里的“上游”指 pkgforge-dev 的打包实现，不表示软件开发商的官方打包方案。

## 范围与查阅规则

- 项目范围以 [AppImage 应用清单](../.github/appimage-apps.json) 为准，按本仓库目录名排序；首列链接对应构建脚本。RunImage、Termux 和 `archive/` 中的归档项目不纳入当前清单。
- 全部当前 AppImage 项目均保留一行。已核实有对应上游仓库和实际构建代码的，填写链接；未查到对应仓库的，两列留空。空白只表示本次未查到，不表示永久不存在，也不免除后续修改前针对当前应用及其别名的查找。
- 本次已核对 pkgforge-dev 的仓库目录，以及填入条目的 README、依赖准备脚本和封装脚本。上游代码链接固定到本次所读 commit，便于定位；需要查看当前实现时从仓库入口进入。这里只确认参考入口，不表示已经审计、测试或采用全部上游代码。
- 修改应用构建脚本前，先查本索引，再阅读对应上游的当前构建代码、相关 workflow、实际调用的 hook / wrapper，以及本仓库应用 README 和已有差异说明。没有单独差异文档时，先阅读现有 README，不为补索引批量创建空文档。
- 上游存在某项处理不等于必须加入。本仓库已确认的采用、未采用和兼容处理继续以对应应用记录及稳定基线为准；拟启用、删除或替换时仍须按 [AGENTS.md](../AGENTS.md) 的必要性判断和授权规则执行。
- 本页覆盖当前各类 AppImage，不表示这些项目都使用 quick-sharun，也不表示全部已标准化；实际打包路线保持各自脚本规定，标准化状态另见 [打包分类](./packaging-classification.md)。

## 项目与上游入口

核对日期：2026-10-30。下表中的依赖、封装和 workflow 均属于同一条目所读的上游 commit。

| 本仓库项目 | 上游打包仓库 | 上游构建代码 | 本仓库说明 |
| --- | --- | --- | --- |
| [adspower-global](../adspower-global/build_adspower-global.sh) |  |  | [README](../adspower-global/README.md) |
| [aionui](../aionui/build_aionui.sh) |  |  |  |
| [alacritty](../alacritty/build_alacritty_linuxdeploy.sh) | [alacritty-AppImage](https://github.com/pkgforge-dev/alacritty-AppImage) | [依赖](https://github.com/pkgforge-dev/alacritty-AppImage/blob/c0ed6bc3a790a581ec568f2d099aba14ab8cb30f/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/alacritty-AppImage/blob/c0ed6bc3a790a581ec568f2d099aba14ab8cb30f/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/alacritty-AppImage/blob/c0ed6bc3a790a581ec568f2d099aba14ab8cb30f/.github/workflows/appimage.yml) | [README](../alacritty/README.md) |
| [alttab](../alttab/build_alttab.sh) |  |  | [README](../alttab/README.md) |
| [android-tools](../android-tools/build_android-tools.sh) | [android-tools-AppImage](https://github.com/pkgforge-dev/android-tools-AppImage) | [依赖](https://github.com/pkgforge-dev/android-tools-AppImage/blob/984ef55eec0461c370c728353405c36a9ce6839e/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/android-tools-AppImage/blob/984ef55eec0461c370c728353405c36a9ce6839e/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/android-tools-AppImage/blob/984ef55eec0461c370c728353405c36a9ce6839e/.github/workflows/appimage.yml) | [README](../android-tools/README.md) |
| [antigravity](../antigravity/build_antigravity.sh) | [Antigravity-AppImage](https://github.com/pkgforge-dev/Antigravity-AppImage) | [依赖](https://github.com/pkgforge-dev/Antigravity-AppImage/blob/0aebfce24807ec0b6c2388305e604da5102ea4f8/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Antigravity-AppImage/blob/0aebfce24807ec0b6c2388305e604da5102ea4f8/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Antigravity-AppImage/blob/0aebfce24807ec0b6c2388305e604da5102ea4f8/.github/workflows/appimage.yml) | [上游差异](../antigravity/docs/pkgforge-differences.md) · [模板差异](../antigravity/docs/template-deviations.md) · [README](../antigravity/README.md) |
| [antigravity-ide](../antigravity-ide/build_antigravity-ide.sh) | [Antigravity-IDE-AppImage](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage) | [依赖](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/.github/workflows/appimage.yml) | [上游差异](../antigravity-ide/docs/pkgforge-differences.md) · [模板差异](../antigravity-ide/docs/template-deviations.md) · [README](../antigravity-ide/README.md) |
| [binance](../binance/build_binance.sh) |  |  | [README](../binance/README.md) |
| [bluemail](../bluemail/build_bluemail.sh) |  |  | [README](../bluemail/README.md) |
| [cc-switch](../cc-switch/build_cc-switch.sh) |  |  | [模板差异](../cc-switch/docs/template-deviations.md) · [README](../cc-switch/README.md) |
| [chatgpt](../chatgpt/build_chatgpt.sh) | [ChatGPT-Desktop-AppImage](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage) | [依赖](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage/blob/0e52cadeafc0229ea9a55415a70a2abc00d0bf07/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage/blob/0e52cadeafc0229ea9a55415a70a2abc00d0bf07/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage/blob/0e52cadeafc0229ea9a55415a70a2abc00d0bf07/.github/workflows/appimage.yml) | [上游差异](../chatgpt/docs/pkgforge-differences.md) · [模板差异](../chatgpt/docs/template-deviations.md) · [README](../chatgpt/README.md) |
| [chromium](../chromium/build_chromium.sh) |  |  | [README](../chromium/README.md) |
| [claude-desktop](../claude-desktop/build_claude-desktop.sh) | [Claude-Desktop-AppImage](https://github.com/pkgforge-dev/Claude-Desktop-AppImage) | [依赖](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/.github/workflows/appimage.yml) | [上游差异](../claude-desktop/docs/pkgforge-differences.md) · [模板差异](../claude-desktop/docs/template-deviations.md) · [README](../claude-desktop/README.md) |
| [copyq](../copyq/build_copyq.sh) | [CopyQ-AppImage](https://github.com/pkgforge-dev/CopyQ-AppImage) | [依赖](https://github.com/pkgforge-dev/CopyQ-AppImage/blob/ea7a390bf0c29590ac7183535bc9cf3b662c18c1/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/CopyQ-AppImage/blob/ea7a390bf0c29590ac7183535bc9cf3b662c18c1/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/CopyQ-AppImage/blob/ea7a390bf0c29590ac7183535bc9cf3b662c18c1/.github/workflows/appimage.yml) | [README](../copyq/README.md) |
| [cursor](../cursor/build_cursor.sh) | [Cursor-AppImage-Enhanced](https://github.com/pkgforge-dev/Cursor-AppImage-Enhanced) | [依赖](https://github.com/pkgforge-dev/Cursor-AppImage-Enhanced/blob/9ba59031ad223ade70bfcafdc14d35c58d123a60/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Cursor-AppImage-Enhanced/blob/9ba59031ad223ade70bfcafdc14d35c58d123a60/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Cursor-AppImage-Enhanced/blob/9ba59031ad223ade70bfcafdc14d35c58d123a60/.github/workflows/appimage.yml) | [模板差异](../cursor/docs/template-deviations.md) · [README](../cursor/README.md) |
| [dconf-editor](../dconf-editor/build_dconf-editor.sh) |  |  | [README](../dconf-editor/README.md) |
| [deepseek-harness-desktop](../deepseek-harness-desktop/build_deepseek-harness-desktop.sh) |  |  | [模板差异](../deepseek-harness-desktop/docs/template-deviations.md) · [README](../deepseek-harness-desktop/README.md) |
| [deskflow](../deskflow/build_deskflow.sh) |  |  | [README](../deskflow/README.md) |
| [dingtalk](../dingtalk/build_dingtalk.sh) |  |  | [README](../dingtalk/README.md) |
| [discord](../discord/build_discord.sh) | [Discord-AppImage](https://github.com/pkgforge-dev/Discord-AppImage) | [依赖](https://github.com/pkgforge-dev/Discord-AppImage/blob/1c4d7852f9272339885497587d2b5f6eb2829ae3/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Discord-AppImage/blob/1c4d7852f9272339885497587d2b5f6eb2829ae3/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Discord-AppImage/blob/1c4d7852f9272339885497587d2b5f6eb2829ae3/.github/workflows/appimage.yml) | [README](../discord/README.md) |
| [escrcpy](../escrcpy/build_escrcpy.sh) |  |  | [README](../escrcpy/README.md) |
| [feishu](../feishu/build_feishu.sh) |  |  | [README](../feishu/README.md) |
| [flameshot](../flameshot/build_flameshot.sh) |  |  |  |
| [folo](../folo/build_folo.sh) |  |  | [README](../folo/README.md) |
| [freedownloadmanager](../freedownloadmanager/build_freedownloadmanager.sh) |  |  | [README](../freedownloadmanager/README.md) |
| [freerdp](../freerdp/build_freerdp.sh) |  |  | [README](../freerdp/README.md) |
| [gemini](../gemini/build_gemini.sh) | [Gemini-Desktop-AppImage](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage) | [依赖](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage/blob/64ae1f91381cb139e83156d5dd0b26eb455b2025/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage/blob/64ae1f91381cb139e83156d5dd0b26eb455b2025/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage/blob/64ae1f91381cb139e83156d5dd0b26eb455b2025/.github/workflows/appimage.yml) | [README](../gemini/README.md) |
| [gitkraken](../gitkraken/build_gitkraken.sh) |  |  | [README](../gitkraken/README.md) |
| [goldendict](../goldendict/build_goldendict.sh) |  |  | [README](../goldendict/README.md) |
| [grok-app](../grok-app/build_grok-app.sh) |  |  | [模板差异](../grok-app/docs/template-deviations.md) · [README](../grok-app/README.md) |
| [grok-bot](../grok-bot/build_grok-bot.sh) |  |  | [模板差异](../grok-bot/docs/template-deviations.md) · [README](../grok-bot/README.md) |
| [hermes-desktop](../hermes-desktop/build_hermes-desktop.sh) |  |  | [README](../hermes-desktop/README.md) |
| [htop](../htop/build_htop.sh) | [htop-AppImage](https://github.com/pkgforge-dev/htop-AppImage) | [依赖](https://github.com/pkgforge-dev/htop-AppImage/blob/138bc266d885f0ac987921a99417aa1278169b76/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/htop-AppImage/blob/138bc266d885f0ac987921a99417aa1278169b76/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/htop-AppImage/blob/138bc266d885f0ac987921a99417aa1278169b76/.github/workflows/appimage.yml) | [上游差异](../htop/docs/pkgforge-differences.md) · [模板差异](../htop/docs/template-deviations.md) · [README](../htop/README.md) |
| [i3wm](../i3wm/build_i3wm.sh) |  |  | [README](../i3wm/README.md) |
| [joplin](../joplin/build_joplin.sh) | [Joplin-Desktop-AppImage](https://github.com/pkgforge-dev/Joplin-Desktop-AppImage) | [依赖](https://github.com/pkgforge-dev/Joplin-Desktop-AppImage/blob/8fbdda883b6d276938d7b67a237032e0282a7252/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Joplin-Desktop-AppImage/blob/8fbdda883b6d276938d7b67a237032e0282a7252/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Joplin-Desktop-AppImage/blob/8fbdda883b6d276938d7b67a237032e0282a7252/.github/workflows/appimage.yml) | [README](../joplin/README.md) |
| [kde-suite](../kde-suite/build_kde_suite.sh) |  |  | [README](../kde-suite/README.md) |
| [keepass](../keepass/build_keepass.sh) |  |  | [README](../keepass/README.md) |
| [keepassxc](../keepassxc/build_keepassxc.sh) | [KeePassXC-AppImage-Enhanced](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced) | [依赖](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced/blob/2e6a99da59e75f2614bb1c8f0800c6b883fe148a/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced/blob/2e6a99da59e75f2614bb1c8f0800c6b883fe148a/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced/blob/2e6a99da59e75f2614bb1c8f0800c6b883fe148a/.github/workflows/appimage.yml) | [README](../keepassxc/README.md) |
| [Keyviz](../Keyviz/build_keyviz.sh) |  |  | [README](../Keyviz/README.md) |
| [kitty](../kitty/build_kitty.sh) |  |  | [README](../kitty/README.md) |
| [mailmaster](../mailmaster/build_mailmaster.sh) |  |  | [README](../mailmaster/README.md) |
| [mediainfo](../mediainfo/build_mediainfo_linuxdeploy.sh) |  |  | [README](../mediainfo/README.md) |
| [mission-center](../mission-center/build_mission-center.sh) |  |  | [README](../mission-center/README.md) |
| [moderncsv](../moderncsv/build_moderncsv.sh) |  |  | [README](../moderncsv/README.md) |
| [mpv](../mpv/build_mpv.sh) | [mpv-AppImage](https://github.com/pkgforge-dev/mpv-AppImage) | [依赖](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/.github/workflows/appimage.yml) | [上游差异](../mpv/docs/pkgforge-differences.md) · [模板差异](../mpv/docs/template-deviations.md) · [README](../mpv/README.md) |
| [newsboat](../newsboat/build_newsboat.sh) |  |  | [README](../newsboat/README.md) |
| [nvtop](../nvtop/build_nvtop.sh) |  |  | [README](../nvtop/README.md) |
| [obs-studio](../obs-studio/build_obs-studio.sh) | [OBS-Studio-AppImage](https://github.com/pkgforge-dev/OBS-Studio-AppImage) | [依赖](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/.github/workflows/appimage.yml) | [上游差异](../obs-studio/docs/pkgforge-differences.md) · [模板差异](../obs-studio/docs/template-deviations.md) · [README](../obs-studio/README.md) |
| [obsidian](../obsidian/build_obsidian.sh) | [Obsidian-AppImage-Enhanced](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced) | [依赖](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/a8b5d56a42c70ce586e7303b1565c8eab0732232/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/a8b5d56a42c70ce586e7303b1565c8eab0732232/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/a8b5d56a42c70ce586e7303b1565c8eab0732232/.github/workflows/appimage.yml) | [README](../obsidian/README.md) |
| [parsec](../parsec/build_parsec.sh) | [parsec-AppImage](https://github.com/pkgforge-dev/parsec-AppImage) | [依赖](https://github.com/pkgforge-dev/parsec-AppImage/blob/312e92ecd1dea7948a9e331f6ae31bb2e88df882/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/parsec-AppImage/blob/312e92ecd1dea7948a9e331f6ae31bb2e88df882/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/parsec-AppImage/blob/312e92ecd1dea7948a9e331f6ae31bb2e88df882/.github/workflows/appimage.yml) | [README](../parsec/README.md) |
| [peazip](../peazip/build_peazip.sh) |  |  | [README](../peazip/README.md) |
| [picom](../picom/build_picom.sh) |  |  | [README](../picom/README.md) |
| [poppler-utils](../poppler-utils/build_poppler-utils.sh) |  |  | [README](../poppler-utils/README.md) |
| [postman](../postman/build_postman.sh) |  |  |  |
| [qemu](../qemu/build_qemu.sh) | [QEMU-AppImage](https://github.com/pkgforge-dev/QEMU-AppImage) | [依赖](https://github.com/pkgforge-dev/QEMU-AppImage/blob/56a5cc40d6b818483e16c20c20b8127b3b91c87c/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/QEMU-AppImage/blob/56a5cc40d6b818483e16c20c20b8127b3b91c87c/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/QEMU-AppImage/blob/56a5cc40d6b818483e16c20c20b8127b3b91c87c/.github/workflows/appimage.yml) | [README](../qemu/README.md) |
| [qq](../qq/build_qq.sh) |  |  | [README](../qq/README.md) |
| [rainlendar2](../rainlendar2/build_rainlendar2.sh) |  |  | [README](../rainlendar2/README.md) |
| [realvnc-rvnc-connect](../realvnc-rvnc-connect/build_realvnc-rvnc-connect.sh) |  |  | [README](../realvnc-rvnc-connect/README.md) |
| [remmina](../remmina/build_remmina.sh) |  |  | [README](../remmina/README.md) |
| [remotedesktopmanager](../remotedesktopmanager/build_remotedesktopmanager.sh) | [Remote-Desktop-Manager-AppImage](https://github.com/pkgforge-dev/Remote-Desktop-Manager-AppImage) | [依赖](https://github.com/pkgforge-dev/Remote-Desktop-Manager-AppImage/blob/1054846c394258f658841f5ebc6c8528483e3e82/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Remote-Desktop-Manager-AppImage/blob/1054846c394258f658841f5ebc6c8528483e3e82/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Remote-Desktop-Manager-AppImage/blob/1054846c394258f658841f5ebc6c8528483e3e82/.github/workflows/appimage.yml) | [README](../remotedesktopmanager/README.md) |
| [ripdrag](../ripdrag/build_ripdrag.sh) |  |  | [README](../ripdrag/README.md) |
| [rofi](../rofi/build_rofi.sh) | [rofi-AppImage](https://github.com/pkgforge-dev/rofi-AppImage) | [依赖](https://github.com/pkgforge-dev/rofi-AppImage/blob/9a3a2a64de1fb38e401a12c75d40e108b2b6b22b/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/rofi-AppImage/blob/9a3a2a64de1fb38e401a12c75d40e108b2b6b22b/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/rofi-AppImage/blob/9a3a2a64de1fb38e401a12c75d40e108b2b6b22b/.github/workflows/appimage.yml) | [README](../rofi/README.md) |
| [rustdesk](../rustdesk/build_rustdesk.sh) | [RustDesk-AppImage-Enhanced](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced) | [依赖](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/cd7be288ae6be5fda55937b1c0afd77a53f77ffa/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/cd7be288ae6be5fda55937b1c0afd77a53f77ffa/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/cd7be288ae6be5fda55937b1c0afd77a53f77ffa/.github/workflows/appimage.yml) | [README](../rustdesk/README.md) |
| [simplescreenrecorder](../simplescreenrecorder/build_simplescreenrecorder.sh) |  |  | [README](../simplescreenrecorder/README.md) |
| [smplayer](../smplayer/build_smplayer.sh) |  |  | [README](../smplayer/README.md) |
| [st](../st/build_st.sh) | [st-AppImage](https://github.com/pkgforge-dev/st-AppImage) | [依赖](https://github.com/pkgforge-dev/st-AppImage/blob/e994638f6786bfdee6d147d6e0e9a476a3ce2119/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/st-AppImage/blob/e994638f6786bfdee6d147d6e0e9a476a3ce2119/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/st-AppImage/blob/e994638f6786bfdee6d147d6e0e9a476a3ce2119/.github/workflows/appimage.yml) | [README](../st/README.md) |
| [stacer](../stacer/build_stacer.sh) |  |  | [README](../stacer/README.md) |
| [stacher](../stacher/build_stacher.sh) |  |  | [README](../stacher/README.md) |
| [sunshine](../sunshine/build_sunshine.sh) |  |  | [README](../sunshine/README.md) |
| [tencent-docs](../tencent-docs/build_tencent-docs.sh) |  |  | [README](../tencent-docs/README.md) |
| [todesk](../todesk/build_todesk.sh) |  |  | [README](../todesk/README.md) |
| [tradingview](../tradingview/build_tradingview.sh) |  |  | [README](../tradingview/README.md) |
| [trae](../trae/build_trae.sh) |  |  |  |
| [trae-work](../trae-work/build_trae-work.sh) |  |  | [README](../trae-work/README.md) |
| [v2rayn](../v2rayn/build_v2rayn.sh) |  |  | [README](../v2rayn/README.md) |
| [ventoy](../ventoy/build_ventoy.sh) |  |  | [README](../ventoy/README.md) |
| [vscode](../vscode/build_vscode.sh) | [Visual-Studio-Code-AppImage](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage) | [依赖](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/.github/workflows/appimage.yml) | [模板差异](../vscode/docs/template-deviations.md) · [README](../vscode/README.md) |
| [webcamoid](../webcamoid/build_webcamoid.sh) | [Webcamoid-AppImage](https://github.com/pkgforge-dev/Webcamoid-AppImage) | [依赖](https://github.com/pkgforge-dev/Webcamoid-AppImage/blob/37f0b62153fab6db90a48e6a3af879198c573c13/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/Webcamoid-AppImage/blob/37f0b62153fab6db90a48e6a3af879198c573c13/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/Webcamoid-AppImage/blob/37f0b62153fab6db90a48e6a3af879198c573c13/.github/workflows/appimage.yml) | [README](../webcamoid/README.md) |
| [wechat](../wechat/build_wechat.sh) |  |  | [README](../wechat/README.md) |
| [wemeet](../wemeet/build_wemeet.sh) | [weemeet-AppImage](https://github.com/pkgforge-dev/weemeet-AppImage) | [依赖](https://github.com/pkgforge-dev/weemeet-AppImage/blob/086708bd1e659138bd4d5bf999bce122e6ab5408/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/weemeet-AppImage/blob/086708bd1e659138bd4d5bf999bce122e6ab5408/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/weemeet-AppImage/blob/086708bd1e659138bd4d5bf999bce122e6ab5408/.github/workflows/appimage.yml) | [README](../wemeet/README.md) |
| [wine](../wine/build_wine.sh) | [wine-AppImage](https://github.com/pkgforge-dev/wine-AppImage) | [依赖](https://github.com/pkgforge-dev/wine-AppImage/blob/18049d52b10a2d47c290aa9a520be7daa5006309/get-dependencies.sh) · [封装](https://github.com/pkgforge-dev/wine-AppImage/blob/18049d52b10a2d47c290aa9a520be7daa5006309/make-appimage.sh) · [workflow](https://github.com/pkgforge-dev/wine-AppImage/blob/18049d52b10a2d47c290aa9a520be7daa5006309/.github/workflows/appimage.yml) | [README](../wine/README.md) |
| [winpodx](../winpodx/build_winpodx_release.sh) |  |  | [README](../winpodx/README.md) |
| [workbuddy](../workbuddy/build_workbuddy.sh) |  |  | [模板差异](../workbuddy/docs/template-deviations.md) · [README](../workbuddy/README.md) |
| [wps-office-cn](../wps-office-cn/build_wps-office-cn.sh) |  |  | [README](../wps-office-cn/README.md) |
| [xephyr](../xephyr/build_xephyr.sh) |  |  | [README](../xephyr/README.md) |
| [xmind](../xmind/build_xmind.sh) |  |  |  |
| [xnviewmp](../xnviewmp/build_xnviewmp.sh) |  |  | [README](../xnviewmp/README.md) |
| [zotero](../zotero/build_zotero.sh) |  |  | [README](../zotero/README.md) |

## 后续维护

新增、归档或调整当前 AppImage 项目时，在获批文档范围内同步维护对应行，保持与应用清单和目录排序一致。确认新的对应上游仓库或入口迁移时，核实实际代码后更新链接；仅修改某个应用时，只核实该应用及其别名，不重新扫描其他项目。GoldenDict 与 GoldenDict-ng、Chromium 与其衍生版等不同项目不得仅凭近似名称互相代填。

上游代码的原文、采用与未采用的具体理由继续放在对应应用的差异文档中，本页只提供入口，不复制另一套判断记录。
