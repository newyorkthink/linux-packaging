# dconf Editor 故障记录

## 45.0.1 读取 GSettings schema 路径时段错误

- 发生阶段：AppImage 启动和运行期间。旧产物多次出现以下断言，随后段错误。

  ```text
  source_manager_try_prepend_dir: assertion 'schemas_dir != NULL' failed
  Segmentation fault (core dumped)
  ```

- 上游原因：[45.0.1 的 `source-manager.vala`](https://github.com/GNOME/dconf-editor/blob/45.0.1/editor/source-manager.vala) 按 `XDG_DATA_DIRS` 的目录数遍历 `GSETTINGS_SCHEMA_DIR` 拆出的数组。前者较长时可能越界。旧、新产物均包含 `gschemas.compiled`。
- 官方修复：[49.rc 发布说明](https://github.com/GNOME/dconf-editor/blob/49.0/NEWS) 记录了该崩溃修复，[49.0 源码](https://github.com/GNOME/dconf-editor/blob/49.0/editor/source-manager.vala) 按 `extra_schema_dirs` 自身长度遍历。
- 打包处理：dconf Editor 的构建环境改用 Ubuntu 26.04，从[官方 APT 仓库](https://packages.ubuntu.com/resolute/dconf-editor)动态获取当前版本。此次配置变更未验证新产物的构建和运行结果。
