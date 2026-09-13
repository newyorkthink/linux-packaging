# 构建修复记录：Python 3.12 与 packaging 模块（2026-09-07）

本文档记录 2026-09-07 当天 GitHub Actions 构建失败的两次故障、原因与修复方式，供后续排查参考。

## 背景

本仓库通过 `.github/workflows/universal.yml` 自动构建 QEMU AppImage 并发布到 `latest` Release。触发方式：

- 定时任务：`cron: "0 0 */6 * *"`
- push 到 `main` 分支
- 手动触发 `workflow_dispatch`

构建直接从 QEMU 上游 master 分支拉取源码编译，因此上游构建依赖要求变化会直接影响本仓库的 CI。

## 故障一：QEMU configure 要求 Python >= 3.12

- **失败运行**：[run 34076791377](https://github.com/newyorkthink/Qemu-AppImage/actions/runs/34076791377)（2026-09-07 02:35 UTC 定时触发，约 9 分钟后失败）
- **报错原文**：

  ```
  ERROR: Cannot use '/usr/bin/python', Python >= 3.12 is required.
         Use --python=/path/to/python to specify a supported Python.
  ```

- **原因**：QEMU 上游 master 的 `configure` 已将最低 Python 版本要求提高到 3.12，而 `ubuntu-22.04` runner 系统自带的 `/usr/bin/python` 是 3.10，版本不满足，configure 阶段直接退出。
- **修复**（commit `8a1b28a` "Fix QEMU build Python 3.12 requirement"）：
  1. 在 workflow 中新增 `actions/setup-python@v5` 步骤，安装 Python 3.12；
  2. `./configure` 增加 `--python="$(command -v python3)"` 参数，显式指定使用 setup-python 安装的 3.12，而不是系统默认 Python。

## 故障二：编译期缺少 Python packaging 模块

- **失败运行**：[run 34097624067](https://github.com/newyorkthink/Qemu-AppImage/actions/runs/34097624067)（第一次修复后触发，约 10 分钟后失败）
- **报错原文**：

  ```
  File "/usr/local/share/glib-2.0/codegen/utils.py", line 22, in <module>
      import packaging.version
  ModuleNotFoundError: No module named 'packaging'
  ninja: build stopped: subcommand failed.
  ```

- **原因**：第一次修复解决了 configure 阶段的问题，configure 顺利通过。但进入 ninja 编译后，glib 的 gdbus-codegen 代码生成脚本同样使用 configure 指定的 Python 3.12 运行，而 setup-python 安装的是一个干净的 Python 3.12 环境，没有 `packaging` 这个第三方模块，导致编译中途失败。
- **修复**（commit `fc09964` "Update universal.yml"）：在构建步骤前新增依赖安装步骤：

  ```yaml
  - name: Install Python build dependencies
    run: |
      python -m pip install --upgrade pip
      python -m pip install packaging
  ```

  这样 `packaging` 被装进与构建实际使用的同一个 Python 3.12 环境。

## 验证结果

- **成功运行**：[run 34099049500](https://github.com/newyorkthink/Qemu-AppImage/actions/runs/34099049500)（2026-09-07 08:08 UTC 触发，耗时 52 分 40 秒）
- 全部步骤（检出代码 → 安装 Python 3.12 → 安装 packaging → 构建 AppImage → 发布 Release）均为 success。
- `latest` Release 已更新，产物为 `qemu.AppImage`（约 119 MB，体积正常）。

## 经验总结

1. **直接编译上游 master 的仓库，CI 会因上游要求变化而突然失败**（本次是 QEMU 把 Python 最低版本从 3.10 提到 3.12）。定时构建失败时优先看 configure / meson 的依赖检查报错。
2. **更换 Python 环境时要保证环境完整**：不光 configure 用指定的 Python，编译期调用的脚本（如 glib 的 gdbus-codegen）也会用同一个 Python。新增 Python 环境后，需要把构建期脚本依赖的 Python 包（如 `packaging`）一并安装到该环境。
3. **修复要一次补齐**：本次第一次修复只解决了 configure 阶段，编译期才暴露第二个问题。修改构建环境时应顺手检查整个构建链路对该环境的依赖。
