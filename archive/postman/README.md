# Postman（已归档）

## 归档状态

- 停用日期：2026-11-05。
- 原因：暂停维护，按需恢复。
- 替代入口：无。
- 原活动目录：`postman/`。
- 原构建入口：`postman/build_postman.sh`。
- 原发布附件：`latest/postman.AppImage`。

本目录保留原始构建脚本及执行权限，退出活动构建和发布。脚本内容原样保留，仅供恢复前查阅；其相对路径按原活动目录编写，不能直接在归档位置执行。

## 用途与原打包方式

Postman 用于开发、调试和测试 API。原脚本从 [Postman 官方 Linux x64 动态下载入口](https://dl.pstmn.io/download/latest/linux64) 获取预编译 tar.gz，保留 Electron 应用目录、资源及官方图标，通过 quick-sharun 封装为 `postman.AppImage`。

原流程在 Arch Linux 构建环境中安装依赖，从包内 `resources/app/package.json` 读取实际版本，准备 desktop 入口和 AppRun，并携带 xdg-utils。归档前由统一 AppImage 工作流的标准 matrix 调度。

## 重新启用

按[归档与恢复说明](../README.md#重新启用)将完整目录移回 `postman/`，恢复活动清单、手动构建选项和活动索引，并移除归档登记。重新启用前核对当前官方来源、包布局和构建要求，再处理恢复过程中实际出现的问题。
