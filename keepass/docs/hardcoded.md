# KeePass 固定配置

## KPScript 重试间隔

- 固定值为 `--aur-source-retry kpscript 1800`。
- 首次发生源文件摘要校验失败时，等待 30 分钟，用新的临时来源目录和构建目录重新下载并安装一次。
- 取值沿用此前约 30 分钟的等待办法。首次下载收到 7,329 字节，校验失败，接着复用该文件再次失败。约 37 分钟后重新下载得到 24,675 字节，SHA-256 校验通过。日志可确定首次下载内容不符合 AUR 配方摘要。

### 原始记录

[首次构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/46025104646/job/140594453039#step:7:1) · [重新构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/46025104646/job/140619314274#step:7:1)

首轮源文件下载、校验和安装错误如下。

```text
2026-11-27T15:52:31.4552306Z ==> Making package: kpscript 2.58-2 (Fri 27 Nov 2026 03:52:31 PM UTC)
2026-11-27T15:52:31.4576480Z ==> Retrieving sources...
2026-11-27T15:52:31.4638644Z   -> Downloading KPScript-2.58.zip...
2026-11-27T15:52:31.6731294Z   % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
2026-11-27T15:52:31.6731670Z                                  Dload  Upload  Total   Spent   Left   Speed
2026-11-27T15:52:31.8511553Z   0      0   0      0   0      0      0      0                              0
2026-11-27T15:52:31.8512041Z 100   7329 100   7329   0      0  19119      0                              0
2026-11-27T15:52:31.8512432Z 100   7329 100   7329   0      0  19118      0                              0
2026-11-27T15:52:31.8512763Z 100   7329 100   7329   0      0  19118      0                              0
2026-11-27T15:52:31.8571051Z   -> Found kpscript
2026-11-27T15:52:31.8590993Z ==> WARNING: Skipping verification of source file PGP signatures.
2026-11-27T15:52:31.8609775Z ==> Validating source files with sha256sums...
2026-11-27T15:52:31.8676320Z     KPScript-2.58.zip ... FAILED
2026-11-27T15:52:31.8738362Z     kpscript ... Passed
2026-11-27T15:52:31.8756844Z ==> ERROR: One or more files did not pass the validity check!
2026-11-27T15:52:31.8760103Z  -> error downloading sources: /home/builduser/.cache/yay/kpscript
2026-11-27T15:52:31.8760460Z 	 context: exit status 1
2026-11-27T15:52:31.8762341Z :: (1/1) Parsing SRCINFO: kpscript
2026-11-27T15:52:32.2761786Z ==> Making package: kpscript 2.58-2 (Fri 27 Nov 2026 03:52:32 PM UTC)
2026-11-27T15:52:32.2769923Z ==> Checking runtime dependencies...
2026-11-27T15:52:32.2866809Z ==> Checking buildtime dependencies...
2026-11-27T15:52:32.2895168Z ==> Retrieving sources...
2026-11-27T15:52:32.2933659Z   -> Found KPScript-2.58.zip
2026-11-27T15:52:32.2968609Z   -> Found kpscript
2026-11-27T15:52:32.2987621Z ==> Validating source files with sha256sums...
2026-11-27T15:52:32.3051929Z     KPScript-2.58.zip ... FAILED
2026-11-27T15:52:32.3114993Z     kpscript ... Passed
2026-11-27T15:52:32.3132645Z ==> ERROR: One or more files did not pass the validity check!
2026-11-27T15:52:32.3135993Z  -> error making: kpscript-exit status 1
2026-11-27T15:52:32.3136373Z  -> Failed to install the following packages. Manual intervention is required:
2026-11-27T15:52:32.3136708Z kpscript - exit status 1
2026-11-27T15:52:32.3466366Z ##[error]Process completed with exit code 1.
```

第二轮源文件下载和首次校验如下。

```text
2026-11-27T16:29:16.1639263Z ==> Making package: kpscript 2.58-2 (Fri 27 Nov 2026 04:29:16 PM UTC)
2026-11-27T16:29:16.1676986Z ==> Retrieving sources...
2026-11-27T16:29:16.1768413Z   -> Downloading KPScript-2.58.zip...
2026-11-27T16:29:16.3841758Z   % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
2026-11-27T16:29:16.3842442Z                                  Dload  Upload  Total   Spent   Left   Speed
2026-11-27T16:29:16.5357627Z   0      0   0      0   0      0      0      0                              0
2026-11-27T16:29:16.5358313Z 100    309 100    309   0      0    876      0                              0
2026-11-27T16:29:16.5361982Z 100    309 100    309   0      0    876      0                              0
2026-11-27T16:29:17.2751646Z   0      0   0      0   0      0      0      0                              0
2026-11-27T16:29:17.2752137Z 100  24675 100  24675   0      0  22593      0   00:01   00:01              0
2026-11-27T16:29:17.2752534Z 100  24675 100  24675   0      0  22592      0   00:01   00:01              0
2026-11-27T16:29:17.2752927Z 100  24675 100  24675   0      0  22591      0   00:01   00:01              0
2026-11-27T16:29:17.2842206Z   -> Found kpscript
2026-11-27T16:29:17.2873761Z ==> WARNING: Skipping verification of source file PGP signatures.
2026-11-27T16:29:17.2903594Z ==> Validating source files with sha256sums...
2026-11-27T16:29:17.3001987Z     KPScript-2.58.zip ... Passed
2026-11-27T16:29:17.3097499Z     kpscript ... Passed
```

## 工作目录

- 从仓库根目录执行构建，`PrecompilePlgx.cs` 据此定位 `keepass/` 中的四份 C# 源码。
- `/tmp/keebuntu-gtk-status-icon` 用于下载和解包托盘插件。`/tmp/keepass-plgx-build` 用于 PLGX 插件下载和隔离的编译缓存。两个临时路径沿用既有构建设置。
- `dist/keepass.AppImage` 和 `dist/version.txt` 位于仓库根目录，与现有构建清单一致。
