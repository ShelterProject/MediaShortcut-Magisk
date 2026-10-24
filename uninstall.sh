#!/system/bin/sh

DM="/data/media/0"
SD="/storage/emulated/0"

for P in "$DM/WhatsApp" "$DM/Telegram" \
         "$SD/WhatsApp" "$SD/Telegram"; do
    if grep -qs " $P " /proc/mounts; then
        umount "$P" 2>/dev/null
    fi
done

for P in "$DM/WhatsApp" "$DM/Telegram"; do
    [ -d "$P" ] && rmdir "$P" 2>/dev/null
done

exit 0
