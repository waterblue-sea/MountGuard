#!/system/bin/sh
MODDIR=${0%/*}
nsenter -t 1 -m -- /system/bin/sh -c ". $MODDIR/common_func.sh; sanitize_mounts"
(
  for delay in 5 15 30; do
    sleep "$delay"
    nsenter -t 1 -m -- /system/bin/sh -c ". $MODDIR/common_func.sh; sanitize_mounts" >/dev/null 2>&1
  done
) </dev/null >/dev/null 2>&1 &