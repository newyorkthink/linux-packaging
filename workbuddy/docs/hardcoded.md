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
