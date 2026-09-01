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
locale_open = "<I18nProvider>"
locale_fixed = "<I18nProvider initialLocale={navigator.language}>"
if locale_fixed not in renderer_text:
    if renderer_text.count(locale_open) != 1:
        die("无法唯一定位 I18nProvider，停止构建，避免错误修改上游源码。")
    renderer_text = renderer_text.replace(locale_open, locale_fixed, 1)
    renderer_path.write_text(renderer_text, encoding="utf-8")

context_path = root / "apps/desktop/src/i18n/context.tsx"
context_text = context_path.read_text(encoding="utf-8")
old_locale_line = "          setLocaleState(normalizeLocale(getConfigDisplayLanguage(config)))"
new_locale_line = (
    "          const configuredLocale = getConfigDisplayLanguage(config)\n"
    "          setLocaleState(\n"
    "            configuredLocale == null ? normalizeLocale(initialLocale) : normalizeLocale(configuredLocale)\n"
    "          )"
)
if "configuredLocale == null ? normalizeLocale(initialLocale)" not in context_text:
    if context_text.count(old_locale_line) != 1:
        die("无法唯一定位 Desktop 语言初始化逻辑，停止构建，避免错误修改上游源码。")
    context_text = context_text.replace(old_locale_line, new_locale_line, 1)
    context_path.write_text(context_text, encoding="utf-8")

preload_path = root / "apps/desktop/electron/preload.ts"
preload_text = preload_path.read_text(encoding="utf-8")
update_bridge_marker = "Hermes standalone Linux AppImage: disable source-checkout desktop self-update"
if update_bridge_marker not in preload_text:
    old_update_bridge = (
        "  updates: {\n"
        "    check: () => ipcRenderer.invoke('hermes:updates:check'),\n"
        "    apply: opts => ipcRenderer.invoke('hermes:updates:apply', opts),\n"
        "    getBranch: () => ipcRenderer.invoke('hermes:updates:branch:get'),\n"
        "    setBranch: name => ipcRenderer.invoke('hermes:updates:branch:set', name),\n"
    )
    new_update_bridge = (
        "  updates: {\n"
        "    // Hermes standalone Linux AppImage: disable source-checkout desktop self-update.\n"
        "    // AppImage updates are distributed through the packaging repository release.\n"
        "    check: () => Promise.resolve(null),\n"
        "    apply: _opts =>\n"
        "      Promise.resolve({\n"
        "        ok: false,\n"
        "        error: 'unavailable',\n"
        "        message: 'Desktop self-update is disabled for this standalone AppImage.'\n"
        "      }),\n"
        "    getBranch: () => Promise.resolve(null),\n"
        "    setBranch: _name => Promise.resolve(null),\n"
    )
    if preload_text.count(old_update_bridge) != 1:
        die("无法唯一定位 Desktop update preload bridge，停止构建，避免错误修改上游源码。")
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
    if about_text.count(version_anchor) != 1:
        die("无法唯一定位 About 版本信息，停止构建，避免错误修改上游源码。")
    about_text = about_text.replace(version_anchor, version_anchor + release_notes_button, 1)

    updates_open = '        <SectionHeading icon={RefreshCw} title={a.updates} />\n'
    updates_close = (
        '        <ListRow\n'
        '          description={a.automaticUpdatesDesc}\n'
        "          hint={a.branchCommit(status?.branch ?? 'unknown', status?.currentSha?.slice(0, 7) ?? 'unknown')}\n"
        '          title={a.automaticUpdates}\n'
        '        />\n'
    )
    if about_text.count(updates_open) != 1 or about_text.count(updates_close) != 1:
        die("无法唯一定位 About 更新区域，停止构建，避免错误修改上游源码。")
    update_wrapper_open = (
        '        {/* Hermes standalone Linux AppImage: hide source-checkout desktop update controls. */}\n'
        '        <div className="hidden">\n'
    )
    about_text = about_text.replace(updates_open, update_wrapper_open + updates_open, 1)
    about_text = about_text.replace(updates_close, updates_close + '        </div>\n', 1)
    about_path.write_text(about_text, encoding="utf-8")

package_path = root / "apps/desktop/package.json"
package_data = json.loads(package_path.read_text(encoding="utf-8"))
extra_resources = package_data.setdefault("build", {}).setdefault("extraResources", [])
libsecret_resource = {
    "from": "build/linux-libs/libsecret-1.so.0",
    "to": "linux-libs/libsecret-1.so.0",
}
if libsecret_resource not in extra_resources:
    extra_resources.append(libsecret_resource)
package_path.write_text(json.dumps(package_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

after_pack_path = root / "apps/desktop/scripts/after-pack.mjs"
after_pack_text = after_pack_path.read_text(encoding="utf-8")
rpath_marker = "Hermes standalone Linux AppImage: add the bundled libsecret directory to Electron RUNPATH"
if rpath_marker not in after_pack_text:
    import_anchor = "import path from 'node:path'\n"
    if import_anchor not in after_pack_text:
        die("无法定位 afterPack import，停止构建，避免错误修改上游源码。")
    after_pack_text = after_pack_text.replace(
        import_anchor,
        "import { execFile } from 'node:child_process'\n"
        "import path from 'node:path'\n"
        "import { promisify } from 'node:util'\n",
        1,
    )

    function_anchor = "export default async function afterPack(context) {\n"
    if function_anchor not in after_pack_text:
        die("无法定位 afterPack 函数，停止构建，避免错误修改上游源码。")

    rpath_patch = r'''export default async function afterPack(context) {
// Hermes standalone Linux AppImage: add the bundled libsecret directory to Electron RUNPATH.
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
  return
}

'''
    after_pack_text = after_pack_text.replace(function_anchor, rpath_patch, 1)
    after_pack_path.write_text(after_pack_text, encoding="utf-8")

checks = [
    (main_path, "Hermes standalone Linux AppImage: detect the Secret Service/KWallet backend directly"),
    (main_path, "Hermes standalone Linux AppImage: map a Chinese system locale to Chromium zh-CN"),
    (main_path, "HERMES_DESKTOP_SAFE_STORAGE_SMOKE_TEST"),
    (renderer_path, "<I18nProvider initialLocale={navigator.language}>"),
    (context_path, "configuredLocale == null ? normalizeLocale(initialLocale)"),
    (preload_path, "Hermes standalone Linux AppImage: disable source-checkout desktop self-update"),
    (about_path, "Hermes standalone Linux AppImage: hide source-checkout desktop update controls"),
    (package_path, '"to": "linux-libs/libsecret-1.so.0"'),
    (after_pack_path, "Hermes standalone Linux AppImage: add the bundled libsecret directory to Electron RUNPATH"),
]
for path, marker in checks:
    if marker not in path.read_text(encoding="utf-8"):
        die(f"补丁校验失败：{path} 缺少 {marker}")

preload_final = preload_path.read_text(encoding="utf-8")
for forbidden in (
    "ipcRenderer.invoke('hermes:updates:check')",
    "ipcRenderer.invoke('hermes:updates:apply'",
    "ipcRenderer.invoke('hermes:updates:branch:get')",
    "ipcRenderer.invoke('hermes:updates:branch:set'",
):
    if forbidden in preload_final:
        die(f"补丁校验失败：preload 仍包含源码自更新 IPC：{forbidden}")

print("Standalone Linux AppImage fixes applied and verified.")
