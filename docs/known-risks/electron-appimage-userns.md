# Ubuntu 上 Electron AppImage 的 SUID sandbox 报错

2026-10-09，`antigravity.AppImage` 在 Ubuntu 桌面（中文 GNOME）上直接运行后退出。先不改构建脚本。别的 Electron / Chromium AppImage 报同一句时，先对照这里。

## 现象

```text
FATAL:sandbox/linux/suid/client/setuid_sandbox_host.cc:166] The SUID sandbox helper binary was found, but is not configured correctly. Rather than run without sandboxing I'm aborting now. You need to make sure that /tmp/.mount_antigrem.../bin/chrome-sandbox is owned by root and has mode 4755.
```

后面还有 zygote 的 `write: Broken pipe`。那是主进程已经退出，不是另一个故障。

## 原因

Ubuntu 24.04 起，AppArmor 默认把 `kernel.apparmor_restrict_unprivileged_userns` 设为 `1`。Chromium 建不了 user namespace，就退回 SUID sandbox。

AppImage 用 FUSE 挂到 `/tmp/.mount_*`，一般是 `nosuid`。挂载里的 `chrome-sandbox` 也不是 root、模式 `4755`。对这个临时路径 `chmod 4755` 不会留下来，下次启动还是原样。

同一份包在允许非特权 user namespace 的系统上可以正常起。构建脚本不用为这件事改。

## 一刀切

这台机器上的 Electron AppImage 都走这组命令。第一条重启后还在，第二条立刻生效：

```bash
echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | sudo tee /etc/sysctl.d/20-apparmor-donotrestrict.conf
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

这是关掉 Ubuntu 加上的那层限制，回到 22.04，以及 Arch、Fedora 的默认。程序仍用自己的 namespace 沙箱，不是 `--no-sandbox`。代价是本地提权面比 24.04 默认略大。

第二行如果报 unknown key，这台机器不是靠这个开关限制的。不要当成已经修好。

2026-10-09 同一台机器执行上述 sysctl 后，`antigravity.AppImage` 能打开，进入登录页。

## 不要这样做

- 不要在构建脚本里把 `chrome-sandbox` 做成 `4755`。打进 AppImage 之后，挂载仍是 `nosuid`，属主也不是 root。
- 不要把 `--no-sandbox` 写进公共启动参数。那是关掉沙箱。用户只是要确认程序本身能否起来时，可以自己临时加上。
