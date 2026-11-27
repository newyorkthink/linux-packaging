#!/usr/bin/env bash

# 本程序专属处理：从仓库根目录预编译功能插件和 Mono 兼容补丁。
test -s "$PLGX_DOWNLOAD_DIR/KeePassOTP.plgx"
test -s "$PLGX_DOWNLOAD_DIR/GlobalSearch.plgx"

mcs \
  -target:exe \
  -out:"$PLGX_PRECOMPILER_EXE" \
  -r:/usr/share/keepass/KeePass.exe \
  "$PLGX_PRECOMPILER_SOURCE"

test -s "$PLGX_PRECOMPILER_EXE"

# 将单个 PLGX 预编译为 DLL，并安装其同目录依赖。
precompile_plgx() {
  local plgx_path="$1"
  local plugin_name="$2"
  local compiled_path
  local output_dir="/usr/share/keepass/Plugins/$plugin_name"

  compiled_path="$(
    HOME="$PLGX_CACHE_HOME" \
    XDG_CONFIG_HOME="$PLGX_CACHE_HOME/.config" \
    XDG_DATA_HOME="$PLGX_CACHE_HOME/.local/share" \
    XDG_CACHE_HOME="$PLGX_CACHE_HOME/.cache" \
    MONO_PATH=/usr/share/keepass \
    mono "$PLGX_PRECOMPILER_EXE" "$plgx_path"
  )"

  test -s "$compiled_path"
  test "$(basename "$compiled_path")" = "$plugin_name.dll"

  rm -rf "$output_dir"
  mkdir -p "$output_dir"
  cp -a "$(dirname "$compiled_path")/." "$output_dir/"
  test -s "$output_dir/$plugin_name.dll"
}

precompile_plgx "$PLGX_DOWNLOAD_DIR/KeePassOTP.plgx" KeePassOTP
precompile_plgx "$PLGX_DOWNLOAD_DIR/GlobalSearch.plgx" GlobalSearch

test -s /usr/share/keepass/Plugins/KeePassOTP/KeePassOTP.dll
test -s /usr/share/keepass/Plugins/KeePassOTP/protobuf-net.dll
test -s /usr/share/keepass/Plugins/KeePassOTP/zxing.dll
test -s /usr/share/keepass/Plugins/KeePassOTP/zxing.presentation.dll
test -s /usr/share/keepass/Plugins/GlobalSearch/GlobalSearch.dll

rm -rf "$PLGX_WORK_DIR"

mcs \
  -target:library \
  -out:/usr/share/keepass/Plugins/MonoMouseWheelFix.dll \
  -r:/usr/share/keepass/KeePass.exe \
  -r:System.Core \
  -r:System.Drawing \
  -r:System.Windows.Forms \
  "$MONO_MOUSE_WHEEL_FIX_SOURCE"

test -f /usr/share/keepass/Plugins/MonoMouseWheelFix.dll

# 窗口布局插件单独编译，避免平铺窗口和 i3 焦点修复影响已经验证的 MonoMouseWheelFix.dll。
KEEPASS_WINDOW_LAYOUT_FIX_SOURCE="$SCRIPT_DIR/KeePassWindowLayoutFix.cs"
KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE="/tmp/KeePassWindowLayoutFix.cs"
test -f "$KEEPASS_WINDOW_LAYOUT_FIX_SOURCE"

# KeePass 插件管理器只使用单选；构建临时源码时关闭 MultiSelect，绕过 Mono ListView.UpdateMultiSelection 的越界路径。
awk '
  /private void Patch\(Form form\)/ { in_patch = 1 }
  in_patch && /string name = form.GetType\(\).FullName;/ {
    print
    print ""
    print "            if(string.Equals(name, PluginsType, StringComparison.Ordinal))"
    print "            {"
    print "                ListView plugins = Find(form, \"m_lvPlugins\") as ListView;"
    print "                if(plugins != null) plugins.MultiSelect = false;"
    print "            }"
    replaced++
    next
  }
  /private void OnFormResize\(object sender, EventArgs e\)/ { in_patch = 0 }
  { print }
  END { if(replaced != 1) exit 1 }
' "$KEEPASS_WINDOW_LAYOUT_FIX_SOURCE" > "$KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE"

test "$(grep -c 'plugins.MultiSelect = false' "$KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE")" -eq 1

mcs \
  -target:library \
  -out:/usr/share/keepass/Plugins/KeePassWindowLayoutFix.dll \
  -r:/usr/share/keepass/KeePass.exe \
  -r:System.Core \
  -r:System.Drawing \
  -r:System.Windows.Forms \
  "$KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE"

rm -f "$KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE"
test -f /usr/share/keepass/Plugins/KeePassWindowLayoutFix.dll
