#!/system/bin/sh

LOG="/data/local/tmp/restore_storage.log"
DM="/data/media/0"
SD="/storage/emulated/0"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | [svc] $1" >> "$LOG"
}

i=0
while [ "$i" -lt 180 ]; do
    [ -d "$SD/Android" ] && [ -d "$SD/Download" ] && break
    sleep 1
    i=$((i + 1))
done
log "storage ready after ${i}s"
sleep 6

MP_UID=$(stat -c %u "$DM/Download" 2>/dev/null)
MP_GID=$(stat -c %g "$DM/Download" 2>/dev/null)
[ -z "$MP_UID" ] && MP_UID=10299
[ -z "$MP_GID" ] && MP_GID=1023

do_mount() {
    NAME="$1"
    SRC="$2"
    DST="$3"

    if [ ! -d "$SRC" ]; then
        log "[$NAME] SKIP: source not found -> $SRC"
        return 1
    fi

    if grep -qs " $DST " /proc/mounts; then
        log "[$NAME] OK: already mounted"
        return 0
    fi

    if [ -e "$DST" ] && [ ! -d "$DST" ]; then
        log "[$NAME] SKIP: a file exists at $DST"
        return 1
    fi

    mkdir -p "$DST" 2>>"$LOG"

    chown "$MP_UID:$MP_GID" "$DST" 2>>"$LOG"
    chmod 2770 "$DST" 2>>"$LOG"
    chcon u:object_r:media_rw_data_file:s0 "$DST" 2>>"$LOG"

    if mount --bind "$SRC" "$DST" 2>>"$LOG"; then
        log "[$NAME] OK: bind $SRC -> $DST"
        return 0
    fi

    log "[$NAME] FAILED: bind mount error"
    return 1
}

log "=== service start (uid=$MP_UID gid=$MP_GID) ==="

do_mount "WhatsApp" \
    "$DM/Android/media/com.whatsapp/WhatsApp" \
    "$DM/WhatsApp"

do_mount "Telegram" \
    "$DM/Android/data/org.telegram.messenger/files/Telegram" \
    "$DM/Telegram"

log "=== service done ==="
exit 0
