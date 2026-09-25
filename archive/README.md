# 归档

不再使用的项目放在这里。脚本和修复记录保留，只是不再构建、不再发布。

以后确认不用的应用，整目录移入 `archive/`，不要直接删除。同时从 workflow 和发布清单里去掉对应入口，并删除 Release 上已经发出的对应产物。`archive/` 里的旧文件默认不再改。

当前仍在使用的 RunImage 和 AppImage 不要放进来。

| 目录 | 停用日期 | 原因 | 替代 |
| --- | --- | --- | --- |
| [jriver](./jriver/README.md) | 2026-09-25 | AppImage 启动慢，而且 bug 多 | [runimage/jriver-media-center](../runimage/jriver-media-center/README.md) 的 `mediacenter36` |
