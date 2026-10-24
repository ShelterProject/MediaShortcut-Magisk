#!/system/bin/sh

LOG="/data/local/tmp/restore_storage.log"
DM="/data/media/0"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | [pfd] $1" >> "$LOG"
}

# Bind di lapisan ext4 (/data/media/0), BUKAN di /storage/emulated/0.
# MediaProvider (FUSE daemon) membaca dari /data/media/0, sehingga mount
# di sini ikut tersaji ke semua aplikasi dan MTP.
bind_media() {
    SRC="$1"
    DST="$2"
    NAME="$3"

    if [ ! -d "$SRC" ]; then
        log "[$NAME] SKIP: source belum ada -> $SRC"
        return 1
    fi

    if grep -qs " $DST " /proc/mounts; then
        log "[$NAME] OK: sudah ter-mount"
        return 0
    fi

    mkdir -p "$DST" 2>>"$LOG"

    if mount --bind "$SRC" "$DST" 2>>"$LOG"; then
        log "[$NAME] OK: bind $SRC -> $DST"
        return 0
    fi

    log "[$NAME] GAGAL bind $DST"
    return 1
}

log "=== post-fs-data start ==="

# Pastikan /data/media/0 sudah tersedia
i=0
while [ ! -d "$DM" ] && [ "$i" -lt 30 ]; do
    sleep 1
    i=$((i + 1))
done

if [ ! -d "$DM" ]; then
    log "FATAL: $DM tidak ada, keluar"
    exit 0
fi

bind_media "$DM/Android/media/com.whatsapp/WhatsApp" \
           "$DM/WhatsApp" "WhatsApp"

bind_media "$DM/Android/data/org.telegram.messenger/files/Telegram" \
           "$DM/Telegram" "Telegram"

log "=== post-fs-data selesai ==="
exit 0
