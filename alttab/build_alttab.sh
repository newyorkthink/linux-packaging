#!/usr/bin/env bash
set -euo pipefail

# 稳定基线说明：
# - 只使用 sagb/alttab 官方最新稳定 GitHub Release 源码，不依赖 AUR 的 alttab/alttab-git 包。
# - 每次构建先读取 releases/latest，再把发布 tag 解析到具体 commit SHA，并按该 commit 下载源码。
# - 使用 Arch Linux 官方仓库提供的构建/运行依赖。
# - 使用 quick-sharun 生成 AppImage。

# 清理上一次构建生成的 AppDir。
rm -rf AppDir || true

# 创建最终输出目录。
mkdir -p dist

# 获取当前系统架构。
ARCH="$(uname -m)"

# 导出 AppImage 架构。
export ARCH

# 创建本次构建使用的临时目录。
WORKDIR="$(mktemp -d)"

# 退出时删除本次构建的临时目录。
trap 'rm -rf "$WORKDIR"' EXIT

# 定义上游最新稳定 Release API 和本地元数据路径。
ALTTAB_RELEASE_API="https://api.github.com/repos/sagb/alttab/releases/latest"
RELEASE_JSON="$WORKDIR/latest-release.json"

# 安装 quick-sharun 打包、源码编译、Release 解析和 Xvfb 验证所需的基础依赖。
yay -S --noconfirm gcc base-devel pkgconf wget git jq binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common xorg-server-xvfb

# 安装 alttab 官方声明的 X11、图形和 uthash 构建/运行依赖。
yay -S --noconfirm libx11 libxmu libxft libxrender libxrandr libpng libxpm uthash

# 读取上游最新稳定 GitHub Release；在 GitHub Actions 中优先使用现有 GH_TOKEN，避免匿名 API 限额。
if [[ -n "${GH_TOKEN:-}" ]]; then
  wget --quiet \
    --header="Authorization: Bearer ${GH_TOKEN}" \
    --header="Accept: application/vnd.github+json" \
    --header="X-GitHub-Api-Version: 2022-11-28" \
    -O "$RELEASE_JSON" \
    "$ALTTAB_RELEASE_API"
else
  wget --quiet \
    --header="Accept: application/vnd.github+json" \
    --header="X-GitHub-Api-Version: 2022-11-28" \
    -O "$RELEASE_JSON" \
    "$ALTTAB_RELEASE_API"
fi

# 确认取得的是非草稿、非预发布的稳定 Release。
jq -e '.draft == false and .prerelease == false' "$RELEASE_JSON" >/dev/null

# 读取最新稳定 Release 的 tag。
ALTTAB_TAG="$(jq -er '.tag_name | strings | select(length > 0)' "$RELEASE_JSON")"

# 拒绝包含路径分隔符、空白或其他异常字符的 tag。
if [[ ! "$ALTTAB_TAG" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]]; then
  echo "错误：上游 Release tag 格式异常：$ALTTAB_TAG" >&2
  exit 1
fi

# 去掉常见的 v 前缀，作为 AppImage 版本信息；没有 v 前缀时保持原值。
ALTTAB_VERSION="${ALTTAB_TAG#v}"

# 将 Release tag 解析到具体 commit；annotated tag 优先使用 peeled commit SHA。
REMOTE_REFS="$(git ls-remote https://github.com/sagb/alttab.git \
  "refs/tags/${ALTTAB_TAG}" \
  "refs/tags/${ALTTAB_TAG}^{}")"
ALTTAB_COMMIT="$(awk -v ref="refs/tags/${ALTTAB_TAG}^{}" '$2 == ref {print $1; exit}' <<< "$REMOTE_REFS")"
if [[ -z "$ALTTAB_COMMIT" ]]; then
  ALTTAB_COMMIT="$(awk -v ref="refs/tags/${ALTTAB_TAG}" '$2 == ref {print $1; exit}' <<< "$REMOTE_REFS")"
fi

# 确认 Release tag 最终解析到有效的 Git commit SHA。
if [[ ! "$ALTTAB_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  echo "错误：无法把上游 Release tag $ALTTAB_TAG 解析到有效 commit。" >&2
  exit 1
fi

# 记录本次实际构建的上游版本和 commit。
printf 'AltTab release: %s\nAltTab commit: %s\n' "$ALTTAB_TAG" "$ALTTAB_COMMIT"

# 按本次已解析出的不可变 commit SHA 构造官方源码下载地址。
ALTTAB_SOURCE_URL="https://codeload.github.com/sagb/alttab/tar.gz/${ALTTAB_COMMIT}"
SOURCE_ARCHIVE="$WORKDIR/alttab-${ALTTAB_COMMIT}.tar.gz"

# 下载该 Release 对应 commit 的官方源码归档。
wget -O "$SOURCE_ARCHIVE" "$ALTTAB_SOURCE_URL"

# 输出本次源码归档 SHA-256，便于构建日志审计。
sha256sum "$SOURCE_ARCHIVE"

# 解压源码并去掉 GitHub 归档自动生成的顶层目录名。
SOURCE_DIR="$WORKDIR/source"
mkdir -p "$SOURCE_DIR"
tar -xzf "$SOURCE_ARCHIVE" -C "$SOURCE_DIR" --strip-components=1

# 确认关键源码、许可证和构建文件存在。
test -f "$SOURCE_DIR/configure"
test -f "$SOURCE_DIR/src/alttab.c"
test -f "$SOURCE_DIR/doc/alttab.svg"
test -f "$SOURCE_DIR/COPYING"

###### 修复桌面图标读取 ######
# 安装解析 XDG desktop 文件所需的 GLib；由 quick-sharun 收集动态依赖。
yay -S --noconfirm glib2

# 为本次下载的上游源码应用图标补丁；不匹配时停止，避免静默生成未修复产物。
patch --batch --forward --fuzz=0 -d "$SOURCE_DIR" -p1 <<'EOF_ICON_PATCH'
--- a/src/icon.c
+++ b/src/icon.c
@@ -29,6 +29,131 @@
 extern int scr;
 extern Window root;
 
+#include <glib.h>
+
+/* Desktop metadata is read once; no launcher commands are executed. */
+static GHashTable *desktop_icons;
+
+static void rememberDesktopIcon(const char *name, const char *icon)
+{
+    if (!name || !*name || !icon || !*icon)
+        return;
+    char *key = g_ascii_strdown(name, -1);
+    if (!g_hash_table_contains(desktop_icons, key))
+        g_hash_table_insert(desktop_icons, key, g_strdup(icon));
+    else
+        g_free(key);
+}
+
+static void scanDesktopIcons(const char *base)
+{
+    char *directory = g_build_filename(base, "applications", NULL);
+    char *paths[] = {directory, NULL};
+    FTS *tree = fts_open(paths, FTS_PHYSICAL | FTS_NOCHDIR, NULL);
+    FTSENT *entry;
+    if (tree) {
+        while ((entry = fts_read(tree)) != NULL) {
+            if ((entry->fts_info != FTS_F && entry->fts_info != FTS_SL) ||
+                !g_str_has_suffix(entry->fts_name, ".desktop"))
+                continue;
+            GKeyFile *file = g_key_file_new();
+            if (g_key_file_load_from_file(file, entry->fts_path,
+                                         G_KEY_FILE_NONE, NULL)) {
+                const char *group = "Desktop Entry";
+                char *icon = g_key_file_get_string(file, group, "Icon", NULL);
+                char *wmclass = g_key_file_get_string(file, group, "StartupWMClass", NULL);
+                char *id = g_strdup(entry->fts_path + strlen(directory) + 1);
+                id[strlen(id) - strlen(".desktop")] = '\0';
+                for (char *p = id; *p; p++)
+                    if (*p == '/') *p = '-';
+                if (!g_key_file_get_boolean(file, group, "Hidden", NULL)) {
+                    rememberDesktopIcon(wmclass, icon);
+                    rememberDesktopIcon(id, icon);
+                }
+                g_free(id);
+                g_free(wmclass);
+                g_free(icon);
+            }
+            g_key_file_free(file);
+        }
+        fts_close(tree);
+    }
+    g_free(directory);
+}
+
+/* Read dimensions before allocating a PNG pixmap, including legacy pixmaps. */
+static int readIconPNGSize(icon_t *ic)
+{
+    FILE *file = fopen(ic->src_path, "rb");
+    TImage image = {0};
+    if (!file)
+        return 0;
+    int ok = pngInit(file, &image);
+    fclose(file);
+    if (!ok)
+        return 0;
+    ic->src_w = image.width;
+    ic->src_h = image.height;
+    png_destroy_read_struct(&image.png_ptr, &image.info_ptr, NULL);
+    return ic->src_w > 0 && ic->src_h > 0 &&
+           ic->src_w <= 16384 && ic->src_h <= 16384;
+}
+
+static icon_t *lookupDesktopIcon(const char *app)
+{
+    if (!desktop_icons) {
+        desktop_icons = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
+        scanDesktopIcons(g_get_user_data_dir());
+        const char * const *dirs = g_get_system_data_dirs();
+        for (int i = 0; dirs[i]; i++)
+            scanDesktopIcons(dirs[i]);
+    }
+    const char *name = g_hash_table_lookup(desktop_icons, app);
+    if (!name)
+        return NULL;
+    icon_t *ic = NULL;
+    if (!g_path_is_absolute(name)) {
+        char *key = g_ascii_strdown(name, -1);
+        char *suffix = strrchr(key, '.');
+        if (suffix && (!strcmp(suffix, ".png") || !strcmp(suffix, ".xpm")))
+            *suffix = '\0';
+        HASH_FIND_STR(g.ic, key, ic);
+        g_free(key);
+        return ic;
+    }
+    const char *suffix = strrchr(name, '.');
+    if (!suffix || strlen(name) >= MAXICONPATHLEN || strlen(app) >= MAXAPPLEN)
+        return NULL;
+    int ext = !g_ascii_strcasecmp(suffix, ".png") ? ICON_EXT_PNG :
+              !g_ascii_strcasecmp(suffix, ".xpm") ? ICON_EXT_XPM : ICON_EXT_UNKNOWN;
+    if (ext == ICON_EXT_UNKNOWN)
+        return NULL;
+    ic = initIcon();
+    if (!ic)
+        return NULL;
+    strcpy(ic->app, app);
+    strcpy(ic->src_path, name);
+    ic->ext = ext;
+    if (ext == ICON_EXT_PNG) {
+        if (!readIconPNGSize(ic)) {
+            deleteIcon(ic);
+            return NULL;
+        }
+    } else {
+        XpmImage image = {0};
+        if (XpmReadFileToXpmImage(ic->src_path, &image, NULL) != XpmSuccess) {
+            XpmFreeXpmImage(&image);
+            deleteIcon(ic);
+            return NULL;
+        }
+        ic->src_w = image.width;
+        ic->src_h = image.height;
+        XpmFreeXpmImage(&image);
+    }
+    HASH_ADD_STR(g.ic, app, ic);
+    return ic;
+}
+
 // PUBLIC:
 
 //
@@ -84,95 +209,39 @@
 // build array of icon directories
 // return the number of elements or 0
 //
-int allocIconDirs(char ** icon_dirs)
-{
-    int hd;
-    char *id2;
-    int id2len;
-    const char *icondir[] = {
-        "/usr/share/icons",
-        "/usr/local/share/icons",
-        "~/.icons",
-        "~/.local/share/icons",
-        "/usr/share/pixmaps",
-        "~/.local/share/pixmaps",
-        NULL
-    };
-    int idndx = 0;
-    int theme_len = strlen(g.option_theme);
-    char *home = getenv("HOME");
-    char *xdgdd = getenv("XDG_DATA_DIRS");
-    bool legacy;
-    char *str1;
-    char *xdg;
-    char *saveptr1;
-    int j;
-    char *k;
-    int idsd;
-
-    for (hd = 0; icondir[hd] != NULL; hd++) {
-        legacy = (strstr (icondir[hd], "pixmap") != NULL);
-        id2len = strlen(icondir[hd]) + 1;
-        if (!legacy)
-            id2len += theme_len + 1;
-        if (icondir[hd][0] == '~') {
-            if (home == NULL)
-                continue;
-            id2len += strlen(home);
-        }
-        id2 = malloc(id2len);
-        if (!id2)
-            return 0;
-        if (icondir[hd][0] == '~')
-            snprintf(id2, id2len, "%s%s", home, icondir[hd] + 1);
-        else
-            snprintf(id2, id2len, "%s", icondir[hd]);
-        if (!legacy) {
-            strcat(id2, "/");
-            strncat(id2, g.option_theme, theme_len);
-        }
-        id2[id2len - 1] = '\0';
-        icon_dirs[idndx] = id2;
-        idndx++;
-    }
-
-    if (xdgdd != NULL) {
-        for (j = 1, str1 = xdgdd; ; j++, str1 = NULL) {
-            xdg = strtok_r(str1, ":", &saveptr1);
-            if (xdg == NULL)
-                break;
-            msg(1, "xdg dir %d: %s\n", j, xdg);
-            // strip trailing "/"'s
-            for (k = xdg + strlen(xdg) - 1; *k == '/'; k--) {
-                *k = '\0';
-            }
-            id2len = strlen(xdg) + strlen("/icons/") + theme_len + 1;
-            id2 = malloc(id2len);
-            if (!id2)
-                return 0;
-            snprintf(id2, id2len, "%s/icons/%s", xdg, g.option_theme);
-            id2[id2len - 1] = '\0';
-            // search for duplicates
-            for (idsd = 0; idsd < idndx; idsd++) {
-                if (strncmp (icon_dirs[idsd], id2, id2len) == 0) {
-                    msg(1, "skip duplicate icon dir: %s\n", id2);
-                    free(id2); id2 = NULL;
-                    break;
-                }
-            }
-            if (id2 != NULL) {
-                icon_dirs[idndx] = id2;
-                idndx++;
-            }
-        }
-    }
-
-    icon_dirs[idndx] = NULL;
-    if (g.debug > 1) {
-        for (idndx = 0; icon_dirs[idndx] != NULL; idndx++)
-            msg(1, "icon dir: %s\n", icon_dirs[idndx]);
-    }
-    return idndx;
+static void appendIconDir(char **dirs, int *count, const char *base,
+                          const char *subdir, const char *theme)
+{
+    if (!base || !g_path_is_absolute(base) || *count >= MAXICONDIRS - 1)
+        return;
+    char *path = g_build_filename(base, subdir, theme, NULL);
+    for (int i = 0; i < *count; i++) {
+        if (!strcmp(dirs[i], path)) {
+            g_free(path);
+            return;
+        }
+    }
+    dirs[(*count)++] = path;
+    dirs[*count] = NULL;
+}
+
+int allocIconDirs(char **icon_dirs)
+{
+    int count = 0;
+    icon_dirs[0] = NULL;
+    const char *user = g_get_user_data_dir();
+    const char * const *system = g_get_system_data_dirs();
+    const char *themes[] = {g.option_theme, "hicolor", NULL};
+    for (int t = 0; themes[t]; t++) {
+        appendIconDir(icon_dirs, &count, g_get_home_dir(), ".icons", themes[t]);
+        appendIconDir(icon_dirs, &count, user, "icons", themes[t]);
+        for (int i = 0; system[i]; i++)
+            appendIconDir(icon_dirs, &count, system[i], "icons", themes[t]);
+    }
+    appendIconDir(icon_dirs, &count, user, "pixmaps", NULL);
+    for (int i = 0; system[i]; i++)
+        appendIconDir(icon_dirs, &count, system[i], "pixmaps", NULL);
+    return count;
 }
 
 //
@@ -182,7 +251,7 @@
 {
     int idndx;
     for (idndx = 0; icon_dirs[idndx] != NULL; idndx++)
-        free(icon_dirs[idndx]);
+        g_free(icon_dirs[idndx]);
 }
 
 //
@@ -191,7 +260,7 @@
 //
 int updateIconsFromFile(icon_t ** ihash)
 {
-    char *icon_dirs[MAXICONDIRS];
+    char *icon_dirs[MAXICONDIRS] = {0};
     int d_c, f_c;
     FTS *ftsp;
     FTSENT *p, *chp;
@@ -209,6 +278,7 @@
     /* Initialize ftsp with as many icon_dirs as possible. */
     chp = fts_children(ftsp, 0);
     if (chp == NULL) {
+        fts_close(ftsp);
         goto out;               /* no files to traverse */
     }
     d_c = f_c = 0;
@@ -404,6 +474,7 @@
             return 0;
         strncpy(ic->app, app, MAXAPPLEN);
         strncpy(ic->src_path, pe->fts_path, MAXICONPATHLEN-1);
+        ic->src_path[MAXICONPATHLEN - 1] = '\0';
         ic->src_w = ix;
         ic->src_h = iy;
         ic->ext = ext;
@@ -416,6 +487,7 @@
         // should we replace the icon?
         if (iconMatchBetter(ix, iy, ic->src_w, ic->src_h, false)) {
             strncpy(ic->src_path, pe->fts_path, MAXICONPATHLEN-1);
+            ic->src_path[MAXICONPATHLEN - 1] = '\0';
             ic->src_w = ix;
             ic->src_h = iy;
             ic->ext = ext;
@@ -431,6 +503,8 @@
 //
 int loadIconContentPNG(icon_t * ic)
 {
+    if (!readIconPNGSize(ic))
+        return 0;
 
     if (!ic->drawable_allocated) {
         ic->drawable = XCreatePixmap(dpy, root, ic->src_w, ic->src_h, XDEPTH);
@@ -442,8 +516,11 @@
     }
 
     if (pngReadToDrawable
-        (ic->src_path, ic->drawable, g.color[COLBG].xcolor.red,
-         g.color[COLBG].xcolor.green, g.color[COLBG].xcolor.blue) == 0) {
+        (ic->src_path, ic->drawable, g.color[COLBG].xcolor.red >> 8,
+         g.color[COLBG].xcolor.green >> 8, g.color[COLBG].xcolor.blue >> 8) == 0) {
+        XFreePixmap(dpy, ic->drawable);
+        ic->drawable = None;
+        ic->drawable_allocated = false;
         msg(-1, "can't read png to drawable: %s\n", ic->src_path);
         return 0;
     }
@@ -497,11 +574,15 @@
     char appl[MAXAPPLEN];
     int l;
 
-    for (l = 0; (*(app + l)) != '\0' && l < MAXAPPLEN; l++)
-        appl[l] = tolower(*(app + l));
+    for (l = 0; (*(app + l)) != '\0' && l < MAXAPPLEN - 1; l++)
+        appl[l] = tolower((unsigned char)*(app + l));
     appl[l] = '\0';
 
     HASH_FIND_STR(g.ic, appl, ic);
+    if (!ic)
+        ic = lookupDesktopIcon(appl);
+    if (ic && ic->ext == ICON_EXT_PNG && ic->drawable == None && !readIconPNGSize(ic))
+        return NULL;
     return ic;
 }
 
@@ -527,6 +608,10 @@
 
 void deleteIconHash(icon_t **ihash)
 {
+    if (desktop_icons) {
+        g_hash_table_destroy(desktop_icons);
+        desktop_icons = NULL;
+    }
     icon_t *iiter, *tmp;
 
     HASH_ITER(hh, *ihash, iiter, tmp) {
EOF_ICON_PATCH

# 传入 GLib 头文件与链接参数，保留现有 configure 和 make 命令。
ALTTAB_GLIB_CFLAGS="$(pkg-config --cflags glib-2.0)"
ALTTAB_GLIB_LIBS="$(pkg-config --libs glib-2.0)"
export CPPFLAGS="${CPPFLAGS:-} $ALTTAB_GLIB_CFLAGS"
export LIBS="${LIBS:-} $ALTTAB_GLIB_LIBS"

# 配置 alttab，保持标准 /usr 安装前缀。
(
  cd "$SOURCE_DIR"
  ./configure --prefix=/usr
)

# 编译 alttab。
make -C "$SOURCE_DIR" -j"$(nproc)"

# 确认编译后的主程序存在且可执行。
test -x "$SOURCE_DIR/src/alttab"

# 创建 AppImage 使用的 desktop 文件；alttab 是 X11 常驻窗口切换器。
cat > "$WORKDIR/alttab.desktop" <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Name=AltTab
Comment=X11 window switcher for minimalistic window managers
Exec=alttab
Icon=alttab
Terminal=false
Categories=Utility;
StartupNotify=false
EOF_DESKTOP

# 校验 desktop 文件语法。
desktop-file-validate "$WORKDIR/alttab.desktop"

# 使用本次最新稳定 Release 的版本号作为 AppImage 版本信息。
export VERSION="$ALTTAB_VERSION"

# 使用上游 SVG 图标。
export ICON="$SOURCE_DIR/doc/alttab.svg"

# 使用本次生成的 desktop 文件。
export DESKTOP="$WORKDIR/alttab.desktop"

# 设置 AppImage 输出目录。
export OUTPATH=./dist

# 固定最终 AppImage 文件名，便于 latest Release 持续覆盖更新。
export OUTNAME="alttab.AppImage"

# 固定 AppImage 主程序为 alttab。
export MAIN_BIN=alttab

# 将刚刚从官方 Release 对应 commit 编译出的 alttab 及其动态依赖封装进 AppDir。
quick-sharun "$SOURCE_DIR/src/alttab"

# 将上游 GPL-3.0 许可证随 AppImage 一并保留。
mkdir -p AppDir/share/licenses/alttab
cp -a "$SOURCE_DIR/COPYING" AppDir/share/licenses/alttab/COPYING

# 生成最终 alttab AppImage。
quick-sharun --make-appimage

# 确认最终 AppImage 文件已经生成且不为空。
test -s ./dist/alttab.AppImage


