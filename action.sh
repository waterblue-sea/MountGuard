#!/system/bin/sh
MODDIR=${0%/*}
echo "========================================="
echo "  MountGuard 自愈与安全软重启工具"
echo "========================================="
nsenter -t 1 -m -- /system/bin/sh -c ". $MODDIR/common_func.sh; sanitize_mounts"
echo "-----------------------------------------"
echo "请选择后续操作 (4 秒内按音量键)："
echo "  [音量+] : 立即执行【安全软重启】(激活模块并重拉守护)"
echo "  [音量-] 或不按键等待 4 秒 : 仅完成热修复并退出"
echo "-----------------------------------------"

KEY=$(timeout 4 getevent -qlc 1 2>/dev/null | grep -E "VOLUMEUP|VOLUMEDOWN")
if echo "$KEY" | grep -q "VOLUMEUP"; then
  echo ">>> 正在执行安全软重启..."
  nsenter -t 1 -m -- /system/bin/sh -c '
    (
      sleep 8
      . /data/adb/modules/mount_guard/common_func.sh
      sanitize_mounts
      sleep 15
      sanitize_mounts
    ) >/dev/null 2>&1 &
    setprop ctl.restart zygote
  '
else
  echo ">>> 已完成在线热修复，无需重启！"
fi