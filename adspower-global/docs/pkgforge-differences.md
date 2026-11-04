# pkgforge 上游核对与取舍

## 核对范围与结果

本次按 `AdsPower`、`adspower-global` 名称核对 pkgforge-dev 组织及 Anylinux-AppImages 对应内容，未找到本程序的专属打包仓库或构建实现。因此没有可记录的对应官方 commit、脚本原文或配套 hook，也未将其他浏览器的专属处理作为本程序的官方实现加入构建。

本次依赖与程序布局采用用户指定的 AUR `adspower-global-bin` 配方作为元数据依据，程序文件仍由该配方指向的 AdsPower 官方 DEB 提供。固定来源见 [PKGBUILD](https://github.com/archlinux/aur/blob/071f26a3236e92008e0ecbd51f8cb588d29e38ef/PKGBUILD) 和 [.SRCINFO](https://github.com/archlinux/aur/blob/071f26a3236e92008e0ecbd51f8cb588d29e38ef/.SRCINFO)。

## 取舍记录

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| pkgforge 的 AdsPower 专属代码或配套文件 | 未启用 | 未启用 | 本次未找到对应实现，不虚构官方命令、原始原因或复用关系。 |
| 旧版应用专属配置 | 本次保留在备份中 | [build_adspower-global_old.sh](../build_adspower-global_old.sh) | 原样保存既有流程和修复依据；正式 build 使用已确认的标准生成稿，后续只按实际问题定向恢复必要部分。 |

本次使用的仓库模板、生成任务、实际入口和版本读取方式见 [模板记录](./template-deviations.md)；历史故障与实机通过结果见 [README](../README.md)。
