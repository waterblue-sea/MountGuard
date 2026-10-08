#!/system/bin/sh
MODDIR=${0%/*}
MODID=${MODDIR##*/}
[ -z "$MODID" ] && MODID="mount_guard"

pkill -9 -f "/data/adb/modules/$MODID/service.sh" 2>/dev/null

nsenter -t 1 -m -- /system/bin/sh -c '
  SELF_LIST=$(awk '\''$4 ~ /^\/(data\/)?adb\/modules\// && $5 ~ /^\/data\/adb\// {print $5}'\'' /proc/1/mountinfo | sort -u)
  for mnt in $SELF_LIST; do
    c=0
    while awk -v m="$mnt" '\''$5 == m {f=1; exit} END {exit !f}'\'' /proc/1/mountinfo; do
      mount --make-private "$mnt" 2>/dev/null
      umount -l "$mnt" 2>/dev/null || break
      c=$((c + 1))
      [ "$c" -ge 64 ] && break
    done
  done
' </dev/null >/dev/null 2>&1

if [ -n "$MODID" ] && [ "$MODID" != "modules" ] && [ "$MODID" != "adb" ]; then
  rm -rf "/data/adb/modules/$MODID" \
         "/data/adb/modules_update/$MODID" \
         "/data/adb/$MODID" \
         "/data/local/tmp/$MODID"
fi
