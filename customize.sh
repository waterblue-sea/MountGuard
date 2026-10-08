# MountGuard Installation & Live Hot-Commit Script
SKIPUNZIP=0

ui_print "========================================="
ui_print "  🛡️ MountGuard 挂载自愈与安全软重启"
ui_print "========================================="

if [ "$KSU" = "true" ]; then
  ui_print "- 检测到 KernelSU 环境 (版本: $KSU_VER_CODE)"
elif [ "$APATCH" = "true" ]; then
  ui_print "- 检测到 APatch 环境 (版本: $APATCH_VER_CODE)"
else
  ui_print "- 检测到 Magisk / 通用 Root 环境"
fi

if ! command -v nsenter >/dev/null 2>&1 || ! command -v awk >/dev/null 2>&1; then
  abort "! 错误：当前系统缺少 nsenter 或 awk 基础工具，无法操作 PID 1 命名空间！"
fi

sed -i 's/\r$//' "$MODPATH"/*.sh "$MODPATH/module.prop" 2>/dev/null

ui_print "- 正在设置脚本可执行权限 (0755)..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
for script in common_func.sh service.sh action.sh uninstall.sh customize.sh; do
  [ -f "$MODPATH/$script" ] && set_perm "$MODPATH/$script" 0 0 0755
done

ui_print "- 正在扫描并在线清洗当前内核挂载表..."
nsenter -t 1 -m -- /system/bin/sh -c ". $MODPATH/common_func.sh; sanitize_mounts" 2>&1 | while read -r line; do
  ui_print "  $line"
done

ui_print "- 正在激活免重启热部署通道..."
(
  sleep 2
  LIVE_DIR="/data/adb/modules/mount_guard"
  UPD_DIR="/data/adb/modules_update/mount_guard"
  if [ -d "$UPD_DIR" ]; then
    mkdir -p "$LIVE_DIR"
    cp -af "$UPD_DIR"/. "$LIVE_DIR"/
    rm -f "$LIVE_DIR/update"
    rm -rf "$UPD_DIR"
    chmod 755 "$LIVE_DIR"/*.sh 2>/dev/null
  fi
  [ -f "$LIVE_DIR/service.sh" ] && sh "$LIVE_DIR/service.sh" </dev/null >/dev/null 2>&1
) </dev/null >/dev/null 2>&1 &

ui_print "========================================="
ui_print "✅ 安装并热修复完成！无需硬重启，刷新模块列表即可直接点击【执行】按钮。"
ui_print "========================================="
