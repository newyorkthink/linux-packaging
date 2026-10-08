#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def die(message: str) -> None:
    raise SystemExit(message)


if len(sys.argv) != 2:
    die("用法：patch_hermes_desktop.py <NousResearch/hermes-agent 源码目录>")

root = Path(sys.argv[1]).resolve()
if not root.is_dir():
    die(f"源码目录不存在：{root}")

main_path = root / "apps/desktop/electron/main.ts"
main_text = main_path.read_text(encoding="utf-8")
keyring_marker = "Hermes standalone Linux AppImage: detect the Secret Service/KWallet backend directly"

if keyring_marker not in main_text:
    anchor = "// Linux: point Chromium at the session's keychain backend so safeStorage can\n"
    if anchor not in main_text:
        die("无法定位 Linux password-store 初始化位置，停止构建，避免错误修改上游源码。")

    keyring_patch = r'''// Hermes standalone Linux AppImage: detect the Secret Service/KWallet backend directly.
// The official `hermes desktop` Python launcher performs this detection before
// starting Electron, but a directly launched AppImage bypasses that launcher.
// Keep the same detection order so KeePassXC Secret Service, GNOME Keyring and
// KWallet can provide Electron safeStorage without forcing plaintext token storage.
if (process.platform === 'linux' && !process.env.HERMES_DESKTOP_PASSWORD_STORE) {
  const kdeVersion = String(process.env.KDE_SESSION_VERSION || '').trim()
  let detectedPasswordStore: string | null = null

  if (kdeVersion === '6') {
    detectedPasswordStore = 'kwallet6'
  } else if (kdeVersion === '5') {
    detectedPasswordStore = 'kwallet5'
  } else if (kdeVersion || process.env.KDE_FULL_SESSION) {
    detectedPasswordStore = 'kwallet'
  } else if (process.env.GNOME_KEYRING_CONTROL) {
    detectedPasswordStore = 'gnome-libsecret'
  } else {
    try {
      execFileSync(
        'dbus-send',
        [
          '--session',
          '--print-reply',
          '--reply-timeout=2000',
          '--dest=org.freedesktop.secrets',
          '/org/freedesktop/secrets',
          'org.freedesktop.DBus.Peer.Ping'
        ],
        { stdio: 'ignore', timeout: 5000 }
      )
      detectedPasswordStore = 'gnome-libsecret'
    } catch {
      // No reachable Secret Service provider; keep the upstream fallback behavior.
    }
  }

  if (detectedPasswordStore) {
    process.env.HERMES_DESKTOP_PASSWORD_STORE = detectedPasswordStore
    console.log(`[hermes] standalone AppImage detected password-store backend: ${detectedPasswordStore}`)
  }
}

'''
    main_text = main_text.replace(anchor, keyring_patch + anchor, 1)

locale_marker = "Hermes standalone Linux AppImage: map a Chinese system locale to Chromium zh-CN"
if locale_marker not in main_text:
    anchor = "// Renderer debugging port. On for dev-server runs"
    if anchor not in main_text:
        die("无法定位 Electron locale 初始化位置，停止构建，避免错误修改上游源码。")

    locale_patch = r'''// Hermes standalone Linux AppImage: map a Chinese system locale to Chromium zh-CN.
// This keeps the first-run / remote-connection UI consistent with a zh_CN Linux
// environment before Hermes has loaded a persisted display.language setting.
if (process.platform === 'linux') {
  const systemLocale = String(
    process.env.LC_ALL || process.env.LC_MESSAGES || process.env.LANG || ''
  ).trim()

  if (/^zh(?:[_-]|$)/i.test(systemLocale)) {
    app.commandLine.appendSwitch('lang', 'zh-CN')
    console.log(`[hermes] standalone AppImage mapped Linux locale ${systemLocale} to zh-CN`)
  }
}

'''
    main_text = main_text.replace(anchor, locale_patch + anchor, 1)

smoke_marker = "HERMES_DESKTOP_SAFE_STORAGE_SMOKE_TEST"
if smoke_marker not in main_text:
    anchor = "// Windows sandbox / GPU breakpoint crash recovery"
    if anchor not in main_text:
        die("无法定位 safeStorage smoke-test 插入位置，停止构建，避免错误修改上游源码。")

    smoke_patch = r'''// CI-only runtime verification for the final standalone AppImage.
// It is inert during normal launches and exits immediately after checking the
// selected backend, real encrypt/decrypt round-trip, and Chinese locale mapping.
if (process.env.HERMES_DESKTOP_SAFE_STORAGE_SMOKE_TEST === '1') {
  app
    .whenReady()
    .then(() => {
      const backend = safeStorage.getSelectedStorageBackend()
      const available = safeStorage.isEncryptionAvailable()
      const locale = app.getLocale()
      console.log(`[hermes-smoke] safeStorage backend=${backend} encryptionAvailable=${available}`)
      console.log(`[hermes-smoke] appLocale=${locale}`)

      if (backend !== 'gnome_libsecret' || !available || !locale.toLowerCase().startsWith('zh')) {
        app.exit(91)
        return
      }

      const original = 'hermes-safe-storage-smoke-test'
      const encrypted = safeStorage.encryptString(original)
      const decrypted = safeStorage.decryptString(encrypted)
      const roundTrip = decrypted === original
      console.log(`[hermes-smoke] safeStorage roundTrip=${roundTrip}`)
      app.exit(roundTrip ? 0 : 92)
    })
    .catch(error => {
      console.error(`[hermes-smoke] failed: ${String(error)}`)
      app.exit(93)
    })
}

'''
    main_text = main_text.replace(anchor, smoke_patch + anchor, 1)

main_path.write_text(main_text, encoding="utf-8")

renderer_path = root / "apps/desktop/src/main.tsx"
renderer_text = renderer_path.read_text(encoding="utf-8")
locale_fixed = "<I18nProvider initialLocale={navigator.language}>"
profile_provider_import = "ProfileI18nProvider as I18nProvider"
if locale_fixed in renderer_text or profile_provider_import in renderer_text:
    # ProfileI18nProvider 只接受 children。系统语言回退在 i18n context 内完成，
    # 再传入 initialLocale 会让 tsc 失败。
    pass
else:
    locale_open = "<I18nProvider>"
    if renderer_text.count(locale_open) != 1:
        die("无法唯一定位 I18nProvider，停止构建，避免错误修改上游源码。")
    renderer_text = renderer_text.replace(locale_open, locale_fixed, 1)
    renderer_path.write_text(renderer_text, encoding="utf-8")

context_path = root / "apps/desktop/src/i18n/context.tsx"
context_text = context_path.read_text(encoding="utf-8")
native_locale_fallback = "setLocaleState(resolveInitialLocale(undefined, machineProfile?.locale))"
if context_text.count(native_locale_fallback) != 1:
    die("无法确认上游 Desktop 系统语言回退逻辑，停止构建，避免覆盖新的 i18n 实现。")

preload_path = root / "apps/desktop/electron/preload.ts"
preload_text = preload_path.read_text(encoding="utf-8")
update_bridge_marker = "Hermes standalone Linux AppImage: disable source-checkout desktop self-update"
if update_bridge_marker not in preload_text:
    update_bridge_candidates = (
        (
            "  updates: {\n"
            "    check: opts => ipcRenderer.invoke('hermes:updates:check', opts),\n"
            "    apply: opts => ipcRenderer.invoke('hermes:updates:apply', opts),\n"
            "    getBranch: () => ipcRenderer.invoke('hermes:updates:branch:get'),\n"
            "    setBranch: name => ipcRenderer.invoke('hermes:updates:branch:set', name),\n"
        ),
        (
            "  updates: {\n"
            "    check: () => ipcRenderer.invoke('hermes:updates:check'),\n"
            "    apply: opts => ipcRenderer.invoke('hermes:updates:apply', opts),\n"
            "    getBranch: () => ipcRenderer.invoke('hermes:updates:branch:get'),\n"
            "    setBranch: name => ipcRenderer.invoke('hermes:updates:branch:set', name),\n"
        ),
    )
    matching_update_bridges = [
        candidate for candidate in update_bridge_candidates if preload_text.count(candidate) == 1
    ]
    if len(matching_update_bridges) != 1:
        die("无法唯一定位 Desktop update preload bridge，停止构建，避免错误修改上游源码。")
    old_update_bridge = matching_update_bridges[0]
    new_update_bridge = (
        "  updates: {\n"
        "    // Hermes standalone Linux AppImage: disable source-checkout desktop self-update.\n"
        "    // AppImage updates are distributed through the packaging repository release.\n"
        "    check: _opts => Promise.resolve(null),\n"
        "    apply: _opts =>\n"
        "      Promise.resolve({\n"
        "        ok: false,\n"
        "        error: 'unavailable',\n"
        "        message: 'Desktop self-update is disabled for this standalone AppImage.'\n"
        "      }),\n"
        "    getBranch: () => Promise.resolve(null),\n"
        "    setBranch: _name => Promise.resolve(null),\n"
    )
    preload_text = preload_text.replace(old_update_bridge, new_update_bridge, 1)
    preload_path.write_text(preload_text, encoding="utf-8")

about_path = root / "apps/desktop/src/app/settings/about-settings.tsx"
about_text = about_path.read_text(encoding="utf-8")
about_marker = "Hermes standalone Linux AppImage: hide source-checkout desktop update controls"
if about_marker not in about_text:
    version_anchor = (
        '          <p className="mt-1 text-xs text-muted-foreground">\n'
        '            {version?.appVersion ? a.version(version.appVersion) : a.versionUnavailable}\n'
        '          </p>\n'
    )
    release_notes_button = (
        '          <Button asChild className="mt-1" size="sm" variant="text">\n'
        '            <a\n'
        '              href={RELEASE_NOTES_URL}\n'
        '              onClick={event => {\n'
        '                event.preventDefault()\n'
        '                void window.hermesDesktop?.openExternal?.(RELEASE_NOTES_URL)\n'
        '              }}\n'
        '              rel="noreferrer"\n'
        '              target="_blank"\n'
        '            >\n'
        '              <ExternalLink className="size-3" />\n'
        '              {a.releaseNotes}\n'
        '            </a>\n'
        '          </Button>\n'
    )
    client_update_card = '          <UpdateStatusCard target="client" />\n'
    if about_text.count(version_anchor) == 1:
        about_text = about_text.replace(version_anchor, version_anchor + release_notes_button, 1)

        updates_open = '        <SectionHeading icon={RefreshCw} title={a.updates} />\n'
        updates_close_candidates = (
            (
                '        <ListRow\n'
                '          description={a.automaticUpdatesDesc}\n'
                "          hint={a.branchCommit(status?.branch ?? 'unknown', status?.currentSha?.slice(0, 7) ?? 'unknown')}\n"
                '          id={settingElementId(SETTING_IDS.about.automaticUpdates)}\n'
                '          title={a.automaticUpdates}\n'
                '        />\n'
            ),
            (
                '        <ListRow\n'
                '          description={a.automaticUpdatesDesc}\n'
                "          hint={a.branchCommit(status?.branch ?? 'unknown', status?.currentSha?.slice(0, 7) ?? 'unknown')}\n"
                '          title={a.automaticUpdates}\n'
                '        />\n'
            ),
        )
        matching_updates_close = [
            candidate for candidate in updates_close_candidates if about_text.count(candidate) == 1
        ]
        if about_text.count(updates_open) != 1 or len(matching_updates_close) != 1:
            die("无法唯一定位 About 更新区域，停止构建，避免错误修改上游源码。")
        updates_close = matching_updates_close[0]
        update_wrapper_open = (
            '        {/* Hermes standalone Linux AppImage: hide source-checkout desktop update controls. */}\n'
            '        <div className="hidden">\n'
        )
        about_text = about_text.replace(updates_open, update_wrapper_open + updates_open, 1)
        about_text = about_text.replace(updates_close, updates_close + '        </div>\n', 1)
        about_path.write_text(about_text, encoding="utf-8")
    elif about_text.count(client_update_card) == 1:
        # v0.21.6 起 About 页不再用 ListRow，Desktop 自更新是 UpdateStatusCard。
        # 只拿掉这一张卡片，远程后端更新保持原样。
        about_text = about_text.replace(
            client_update_card,
            "          {/* Hermes standalone Linux AppImage: hide source-checkout desktop update controls. */}\n"
            "          {null}\n",
            1,
        )
        about_path.write_text(about_text, encoding="utf-8")
    else:
        die("无法唯一定位 About 的 Desktop 更新入口，停止构建，避免错误修改上游源码。")

package_path = root / "apps/desktop/package.json"
package_data = json.loads(package_path.read_text(encoding="utf-8"))
build_config = package_data.setdefault("build", {})
build_config["publish"] = None
after_pack_hook = "scripts/after-pack-appimage.mjs"
upstream_after_pack = "scripts/after-pack.mjs"
existing_after_pack_hook = build_config.get("afterPack")
upstream_after_pack_path = root / "apps/desktop" / upstream_after_pack
chain_upstream_after_pack = False
if existing_after_pack_hook in (None, after_pack_hook):
    pass
elif existing_after_pack_hook == upstream_after_pack and upstream_after_pack_path.is_file():
    # v2026.9.24 恢复了 macOS locale 用的 after-pack.mjs，Linux 上它会直接返回。
    # 保留调用，避免覆盖上游逻辑，再追加 AppImage 的 libsecret RUNPATH。
    chain_upstream_after_pack = True
else:
    die(f"上游已配置未知 afterPack hook：{existing_after_pack_hook}，停止构建，避免覆盖上游逻辑。")
build_config["afterPack"] = after_pack_hook
extra_resources = build_config.setdefault("extraResources", [])
libsecret_resource = {
    "from": "build/linux-libs/libsecret-1.so.0",
    "to": "linux-libs/libsecret-1.so.0",
}
if libsecret_resource not in extra_resources:
    extra_resources.append(libsecret_resource)
package_path.write_text(json.dumps(package_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# electron-builder 实际读取的是 electron-builder.config.cjs，不是 package.json 的 build。
# v0.21.6 起 afterPack 和 extraResources 都在这个文件里，只改 package.json 不会打进 AppImage。
config_path = root / "apps/desktop/electron-builder.config.cjs"
config_text = config_path.read_text(encoding="utf-8")
cjs_upstream_after_pack = "  afterPack: 'scripts/after-pack.mjs',"
cjs_appimage_after_pack = "  afterPack: 'scripts/after-pack-appimage.mjs',"
if cjs_upstream_after_pack in config_text:
    if config_text.count(cjs_upstream_after_pack) != 1 or not upstream_after_pack_path.is_file():
        die("无法唯一定位 electron-builder.config.cjs 的 afterPack，停止构建。")
    chain_upstream_after_pack = True
    config_text = config_text.replace(cjs_upstream_after_pack, cjs_appimage_after_pack, 1)
elif cjs_appimage_after_pack not in config_text:
    die("electron-builder.config.cjs 的 afterPack 不是预期的上游 hook，停止构建。")
libsecret_resource_cjs = (
    "    {\n"
    "      from: 'build/linux-libs/libsecret-1.so.0',\n"
    "      to: 'linux-libs/libsecret-1.so.0'\n"
    "    },\n"
)
icon_resource_cjs = (
    "    {\n"
    "      from: 'assets/icon.ico',\n"
    "      to: 'icon.ico'\n"
    "    }\n"
)
if "build/linux-libs/libsecret-1.so.0" not in config_text:
    if config_text.count(icon_resource_cjs) != 1:
        die("无法唯一定位 electron-builder.config.cjs 的 extraResources，停止构建。")
    config_text = config_text.replace(icon_resource_cjs, libsecret_resource_cjs + icon_resource_cjs, 1)
config_path.write_text(config_text, encoding="utf-8")

after_pack_path = root / "apps/desktop/scripts/after-pack-appimage.mjs"
upstream_prelude = ""
if chain_upstream_after_pack:
    upstream_prelude = (
        "import upstreamAfterPack from './after-pack.mjs'\n"
        "\n"
    )
upstream_call = ""
if chain_upstream_after_pack:
    upstream_call = (
        "  if (typeof upstreamAfterPack === 'function') {\n"
        "    await upstreamAfterPack(context)\n"
        "  }\n"
        "\n"
    )
after_pack_text = (
    "import { execFile } from 'node:child_process'\n"
    "import path from 'node:path'\n"
    "import { promisify } from 'node:util'\n"
    f"{upstream_prelude}"
    "\n"
    "export default async function afterPack(context) {\n"
    f"{upstream_call}"
    r'''  // Hermes standalone Linux AppImage: add the bundled libsecret directory to Electron RUNPATH.
  // Chromium loads libsecret with dlopen("libsecret-1.so.0"), so selecting
  // gnome-libsecret alone is insufficient on hosts where the client library is absent.
  if (context.electronPlatformName === 'linux') {
    const productName = context.packager?.appInfo?.productFilename || 'Hermes'
    const executable = path.join(context.appOutDir, productName)
    const execFileAsync = promisify(execFile)
    const { stdout } = await execFileAsync('patchelf', ['--print-rpath', executable])
    const bundledLibsecretRpath = '$ORIGIN/resources/linux-libs'
    const existingRpath = stdout.trim()
    const rpathParts = existingRpath ? existingRpath.split(':').filter(Boolean) : []

    if (!rpathParts.includes(bundledLibsecretRpath)) {
      rpathParts.push(bundledLibsecretRpath)
      await execFileAsync('patchelf', ['--set-rpath', rpathParts.join(':'), executable])
    }

    console.log(`[after-pack] Linux Electron RUNPATH includes ${bundledLibsecretRpath}`)
  }
}
'''
)
after_pack_path.write_text(after_pack_text, encoding="utf-8")

checks = [
    (main_path, "Hermes standalone Linux AppImage: detect the Secret Service/KWallet backend directly"),
    (main_path, "Hermes standalone Linux AppImage: map a Chinese system locale to Chromium zh-CN"),
    (main_path, "HERMES_DESKTOP_SAFE_STORAGE_SMOKE_TEST"),
    (context_path, native_locale_fallback),
    (preload_path, "Hermes standalone Linux AppImage: disable source-checkout desktop self-update"),
    (about_path, "Hermes standalone Linux AppImage: hide source-checkout desktop update controls"),
    (package_path, '"publish": null'),
    (package_path, '"afterPack": "scripts/after-pack-appimage.mjs"'),
    (package_path, '"to": "linux-libs/libsecret-1.so.0"'),
    (config_path, "afterPack: 'scripts/after-pack-appimage.mjs'"),
    (config_path, "build/linux-libs/libsecret-1.so.0"),
    (after_pack_path, "Hermes standalone Linux AppImage: add the bundled libsecret directory to Electron RUNPATH"),
]
for path, marker in checks:
    if marker not in path.read_text(encoding="utf-8"):
        die(f"补丁校验失败：{path} 缺少 {marker}")

renderer_final = renderer_path.read_text(encoding="utf-8")
if (
    "<I18nProvider initialLocale={navigator.language}>" not in renderer_final
    and "ProfileI18nProvider as I18nProvider" not in renderer_final
):
    die("补丁校验失败：无法确认 Desktop 初始语言来源。")

if chain_upstream_after_pack:
    hook_text = after_pack_path.read_text(encoding="utf-8")
    if "import upstreamAfterPack from './after-pack.mjs'" not in hook_text:
        die("补丁校验失败：未保留上游 afterPack hook。")
    if "await upstreamAfterPack(context)" not in hook_text:
        die("补丁校验失败：未调用上游 afterPack hook。")

preload_final = preload_path.read_text(encoding="utf-8")
for forbidden in (
    "ipcRenderer.invoke('hermes:updates:check')",
    "ipcRenderer.invoke('hermes:updates:apply'",
    "ipcRenderer.invoke('hermes:updates:branch:get')",
    "ipcRenderer.invoke('hermes:updates:branch:set'",
):
    if forbidden in preload_final:
        die(f"补丁校验失败：preload 仍包含源码自更新 IPC：{forbidden}")


builder_path = root / "apps/desktop/scripts/run-electron-builder.mjs"
builder_text = builder_path.read_text(encoding="utf-8")
icon_tool_marker = "Hermes standalone Linux AppImage: keep copied icon-tool.js in CommonJS"
copy_anchor = "    fs.cpSync(directory, destination, { recursive: true, verbatimSymlinks: true })\n"
if icon_tool_marker not in builder_text:
    if builder_text.count(copy_anchor) != 1:
        die("无法唯一定位打包工具复制位置，停止构建，避免错误修改上游源码。")
    builder_text = builder_text.replace(
        copy_anchor,
        copy_anchor
        + "    // Hermes standalone Linux AppImage: keep copied icon-tool.js in CommonJS.\n"
        + "    // apps/desktop is \"type\": \"module\", so Node treats a nearby .js file as ESM\n"
        + "    // and the upstream icon tool's require() fails.\n"
        + "    if (!fs.existsSync(path.join(destination, 'package.json'))) {\n"
        + "      fs.writeFileSync(path.join(destination, 'package.json'), '{\"type\":\"commonjs\"}\\n')\n"
        + "    }\n",
        1,
    )
    builder_path.write_text(builder_text, encoding="utf-8")
if icon_tool_marker not in builder_path.read_text(encoding="utf-8"):
    die("补丁校验失败：未把 icon-tool 固定为 CommonJS。")

print("Standalone Linux AppImage fixes applied and verified.")
