# Media Shortcuts

A small Magisk module that gives you back the old `/sdcard/Telegram` and
`/sdcard/WhatsApp` folders.

Since Android 11, both apps keep their files in places that are either
awkward or straight up locked down:

| App | Where the files actually live |
| --- | --- |
| WhatsApp | `/sdcard/Android/media/com.whatsapp/WhatsApp` |
| Telegram | `/sdcard/Android/data/org.telegram.messenger/files/Telegram` |

`Android/media` is readable by most file managers, but `Android/data` is not.
On many phones even MTP refuses to show it. So the module bind mounts both
locations back to the storage root:

```
/sdcard/WhatsApp  ->  Android/media/com.whatsapp/WhatsApp
/sdcard/Telegram  ->  Android/data/org.telegram.messenger/files/Telegram
```

Same files, two names. Nothing is copied or moved, and writes through the
shortcut land in the real folder, so both apps keep working normally.

## Requirements

- Magisk 24 or newer (any root that runs `service.sh` from `/data/adb/modules`)
- Android 11 and up

## Install

Grab the zip from the releases, then either:

- Magisk app -> Modules -> Install from storage, or
- from a shell:

```sh
adb push media_shortcuts-v1.0.zip /sdcard/Download/
adb shell su -c "magisk --install-module /sdcard/Download/media_shortcuts-v1.0.zip"
```

Reboot afterwards. The shortcuts appear about 30 seconds after boot finishes,
because the script waits for external storage to be mounted first.

## Uninstall

Remove the module from the Magisk app. `uninstall.sh` unmounts the shortcuts
and deletes the empty mount points. Your real folders are never touched.

## How it works

`service.sh` runs at late boot, waits until `/sdcard/Android` and
`/sdcard/Download` exist, then bind mounts the source folders onto
`/data/media/0/WhatsApp` and `/data/media/0/Telegram`.

The mount happens on the raw `/data` filesystem rather than on
`/storage/emulated/0`, because MediaProvider serves the FUSE view from
`/data/media/0`. Mounting there means every app, file manager and MTP client
sees the shortcut, not just root.

One detail that matters: the mount point has to be owned by the media provider
UID, not root. If it stays `root:root 2750`, apps get "Permission denied" even
though the mount itself succeeded. The script sets ownership, `chmod 2770` and
the `media_rw_data_file` SELinux context before mounting.

Nothing is mounted in `post-fs-data`. At that stage `/data/media/0` exists but
the app folders do not, so it would always fail. That file is left over from an
earlier version and is not used.

## Log

```
/data/local/tmp/restore_storage.log
```

Every boot appends a few lines. If a shortcut is missing, that log says why:
source not found, already mounted, or bind failed.

## Building

Three scripts, pick whichever fits your shell. All of them produce the same
zip in the module folder.

```sh
# Windows, PowerShell
.\build.ps1

# Windows, double-click friendly
build.bat

# Git Bash, WSL, Linux
./build.sh
```

The zip is named `<id>-<version>.zip`, taken from `module.prop`. Build scripts,
this README and the LICENSE are excluded from the package.

## Notes

- This does not change how the apps save files, it only adds a second path.
- If you clear app data or reinstall Telegram, the folder comes back on next
  boot with no action needed.
- Some file managers cache the root listing. If the folder does not show up,
  pull to refresh or restart the file manager.

## License

MIT, see [LICENSE](LICENSE).
