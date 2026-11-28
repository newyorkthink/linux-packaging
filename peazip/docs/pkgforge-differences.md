# PeaZip 上游打包差异

[上游打包参考索引](../../Docs/upstream-packaging-index.md)中的 PeaZip 条目没有登记 pkgforge-dev 仓库。本次针对 PeaZip 名称核对，未找到匹配的 pkgforge-dev 打包实现。

当前使用 [PeaZip 正式 Release](https://github.com/peazip/PeaZip/releases)的 Qt6 amd64 DEB。已核对 [Arch Extra 的 PeaZip 包](https://archlinux.org/packages/extra/x86_64/peazip/)，本项目沿用此前实测使用的官网 DEB 布局、Qt6Pas 与包自带归档后端。当前启用的处理见[专属差异](./template-deviations.md)。
