# WorkBuddy 写死的路径

## `/opt/WorkBuddy`

- 为什么写死：AUR 包把程序装在这个目录。`/usr/bin/workbuddy` 是 shell，不是入口。脚本不在构建时再查询安装位置。
- 写死的内容：`/opt/WorkBuddy`
- 作用：把这个目录里的全部内容放进 `AppDir/bin`。
- 当初报错：没有。这是包装进去的目录，不是扫描失败后补的路径。

## `/usr/share/icons/hicolor/512x512/apps/workbuddy.png`

- 为什么写死：图标由安装好的 AUR 包放在这个路径。脚本不在构建时再查询。
- 写死的内容：`/usr/share/icons/hicolor/512x512/apps/workbuddy.png`
- 作用：交给 quick-sharun 作为包内图标。
- 当初报错：没有。这是包装用的图标路径，不是扫描失败后补的路径。

## `/usr/share/applications/workbuddy.desktop`

- 为什么写死：桌面入口由安装好的 AUR 包放在这个路径。脚本不在构建时再查询。
- 写死的内容：`/usr/share/applications/workbuddy.desktop`
- 作用：交给 quick-sharun 作为桌面入口。
- 当初报错：没有。这是包装用的桌面入口路径，不是扫描失败后补的路径。

## `/usr/bin/ls`、`/usr/bin/mkdir`、`/usr/bin/ln`、`/usr/bin/grep`

- 为什么写死：AppImage 的 PATH 里这四个名字是包装脚本。程序用 `/bin/sh` 执行时，dash 不认识脚本里的括号。
- 写死的内容：`/usr/bin/ls`、`/usr/bin/mkdir`、`/usr/bin/ln`、`/usr/bin/grep`
- 作用：交给 quick-sharun，让包里使用这四个真实命令。
- 当初报错全文：

```text
/tmp/.mount_workbremp10445982116532899481/bin/mkdir: 620: Syntax error: "(" unexpected (expecting ")")
/tmp/.mount_workbremp10445982116532899481/bin/ln: 620: Syntax error: "(" unexpected (expecting ")")
/tmp/.mount_workbremp10445982116532899481/bin/grep: 620: Syntax error: "(" unexpected (expecting ")")
```

同一包里直接执行 `ls` 也报 `Syntax error: "(" unexpected`。改用 `/bin/ls` 可以正常读写文件。
