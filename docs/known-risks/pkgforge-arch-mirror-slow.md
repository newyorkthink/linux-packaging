# pkgforge Arch 容器的第一条源有时候会超时

2026-10-28。现在没有超时。这条源不是一直坏，只是有时候会慢到 `pacman` 放弃这次下载。这是上游那条源的情况，不是本仓库某个应用的脚本坏了。不改 workflow，不换源，不写死别的地址。

这里有记录，不表示要去改。后面的 AI 如果再看到下面这种日志，按「上游 Bug 默认保留」说明，不要自行处理。不要去查 Actions 链接，运行记录会被自动清理。

## 我们怎么用到它

仓库没有复制 pkgforge 的代码。Actions 把任务放进他们发布的容器 `ghcr.io/pkgforge-dev/archlinux`。容器里的系统、`pacman` 和 `/etc/pacman.d/mirrorlist` 都是他们的。

源列表第一条是：

```text
Server = https://ghcr.mirror.archlinux.pkgforge.dev/$arch/$repo
```

后面还有 Arch 官方源，例如 `https://geo.mirror.pkgbuild.com/$repo/os/$arch`。`$arch`、`$repo` 由 `pacman` 替换，浏览器不会替换。

进容器之后、应用脚本之前，工作流做这几步，都没有改他们的容器：

1. `pacman -Sy --noconfirm git`
2. `pkgforge-dev/anylinux-setup-action`，装上 `quick-sharun`
3. 本仓库的构建 Action 再装 `yay`，然后运行该应用自己的 `build_*.sh`

`build_*.sh` 再调用已经装好的 `quick-sharun`。超时发生时，失败在第 1 步，应用脚本还没开始。

## 现在的情况

2026-10-28 这次 CC Switch 构建没有超时。`Pre-install Git` 大约 3 秒完成，后面的打包也完成了。workflow 没有为这件事改过。

浏览器直接打开 `https://ghcr.mirror.archlinux.pkgforge.dev/$arch/$repo` 会看到：

```text
not /ARCH/REPO/FILE, /ARCH/REPO:TAG/FILE or /ARCH/REPO@sha256:HEX/FILE
```

那是地址没换成真实路径。`https://ghcr.mirror.archlinux.pkgforge.dev/x86_64/extra/extra.db` 会下载文件，没有网页。当时这个文件能下，只说明那一刻源是通的。

## 有时候会怎样

`pacman` 先用第一条。这条源慢到不足 1 字节/秒时，并行下载里已经失败的文件不会改去后面的官方源。日志里就只出现 `ghcr.mirror.archlinux.pkgforge.dev`，然后整次安装失败。

这不是 archlinux.org 打不开，也不是应用自己的安装包下不下来。用这个容器的应用都会走同一步，不限于某一次失败的那个应用。

## 当时的原始记录

2026-10-28 07:50 UTC，CC Switch 构建在装 `git` 时失败。命令是 `pacman -Sy --noconfirm git`。退出码 1。原文：

```text
:: Synchronizing package databases...
error: failed retrieving file 'extra.db' from ghcr.mirror.archlinux.pkgforge.dev : Operation too slow. Less than 1 bytes/sec transferred the last 10 seconds
 core downloading...
 extra downloading...
resolving dependencies...
looking for conflicting packages...

Packages (7) db5.3-5.3.28-7  perl-5.44.0-1  perl-error-0.17031-1  perl-mailtools-2.22-3  perl-timedate-2.35-1  zlib-ng-2.3.3-1  git-2.56.0-1

Total Download Size:    29.92 MiB
Total Installed Size:  112.89 MiB

:: Proceed with installation? [Y/n]
:: Retrieving packages...
error: failed retrieving file 'perl-5.44.0-1-x86_64.pkg.tar.zst' from ghcr.mirror.archlinux.pkgforge.dev : Operation too slow. Less than 1 bytes/sec transferred the last 10 seconds
error: failed retrieving file 'db5.3-5.3.28-7-x86_64.pkg.tar.zst' from ghcr.mirror.archlinux.pkgforge.dev : Operation too slow. Less than 1 bytes/sec transferred the last 10 seconds
warning: too many errors from ghcr.mirror.archlinux.pkgforge.dev, skipping for the remainder of this transaction
error: failed retrieving file 'perl-timedate-2.35-1-any.pkg.tar.zst' from ghcr.mirror.archlinux.pkgforge.dev : Operation too slow. Less than 1 bytes/sec transferred the last 10 seconds
error: failed retrieving file 'zlib-ng-2.3.3-1-x86_64.pkg.tar.zst.sig' from ghcr.mirror.archlinux.pkgforge.dev : Operation too slow. Less than 1 bytes/sec transferred the last 10 seconds
error: failed retrieving file 'git-2.56.0-1-x86_64.pkg.tar.zst.sig' from ghcr.mirror.archlinux.pkgforge.dev : Operation too slow. Less than 1 bytes/sec transferred the last 10 seconds
warning: failed to retrieve some files
error: failed to commit transaction (download library error)
 perl-5.44.0-1-x86_64 downloading...
 git-2.56.0-1-x86_64 downloading...
 db5.3-5.3.28-7-x86_64 downloading...
 zlib-ng-2.3.3-1-x86_64 downloading...
 perl-timedate-2.35-1-any downloading...
 perl-mailtools-2.22-3-any downloading...
 perl-error-0.17031-1-any downloading...
Errors occurred, no packages were upgraded.
Process completed with exit code 1.
```

同一天更早的一次 CC Switch 构建也是这句：`Operation too slow. Less than 1 bytes/sec transferred the last 10 seconds`。日志里的主机只有 `ghcr.mirror.archlinux.pkgforge.dev`。那次在装 `git` 之后，安装 curl、wget 和基础包时又出现同样的超时。

## 不要这样做

- 不要把这条源注释掉，也不要改成后面的官方源。
- 不要在 workflow 或脚本里写死别的镜像地址。
- 不要只给某一个应用加判断。这是容器里的源，不是那个应用的脚本。
- 不要把以前撤回的 workflow 改动再拿回来。那些改动不在 `main` 上，也不是当前做法。
- 不要把「现在没有超时」写成「这条源不会再超时」。记录留着，是因为以前出现过，以后还可能再碰到。

只有用户在知道这是上游源有时候会慢之后，仍然明确要求改，并批准具体改哪些文件，才允许动构建。
