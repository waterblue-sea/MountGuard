#!/system/bin/sh
MODDIR=${0%/*}
echo "========================================="
echo "  🛡️ MountGuard 自愈与安全软重启工具"
echo "========================================="
nsenter -t 1 -m -- /system/bin/sh -c ". $MODDIR/common_func.sh; sanitize_mounts"
echo "-----------------------------------------"
echo "请选择后续操作 (4 秒内按音量键)："
echo "  [音量+] : 立即执行【安全软重启】(激活模块并重拉守护)"
echo "  [音量-] 或不按键等待 4 秒 : 仅完成热修复并退出"
echo "-----------------------------------------"

detect_volume_key() {
  timeout 4 getevent -ql 2>/dev/null | while read -r line; do
    case "$line" in
      *KEY_VOLUMEUP*DOWN*)   echo "UP"; pkill -f "getevent -ql" 2>/dev/null; break ;;
      *KEY_VOLUMEDOWN*DOWN*) echo "DOWN"; pkill -f "getevent -ql" 2>/dev/null; break ;;
    esac
  done
}

KEY=$(detect_volume_key)
if [ "$KEY" = "UP" ]; then
  echo ">>> 检测到 [音量+]，正在执行安全软重启..."
  nsenter -t 1 -m -- /system/bin/sh -c '
    . /data/adb/modules/mount_guard/common_func.sh
    sanitize_mounts
    (
      # 软重启后重拉各活跃模块的 service.sh 并执行多轮挂载消杀
      sleep 5
      for m in /data/adb/modules/*; do
        [ ! -d "$m" ] || [ -f "$m/disable" ] || [ -f "$m/remove" ] && continue
        [ "${m##*/}" = "mount_guard" ] && continue
        [ -f "$m/service.sh" ] && sh "$m/service.sh" </dev/null >/dev/null 2>&1 &
      done
      sleep 3
      sanitize_mounts
      sleep 12
      sanitize_mounts
      sleep 20
      sanitize_mounts
    ) </dev/null >/dev/null 2>&1 &
    setprop ctl.restart zygote
  '
else
  echo ">>> 已完成在线热修复，无需重启！"
fi
