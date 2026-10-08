#!/system/bin/sh

commit_pending_modules() {
  if [ -d "/data/adb/modules_update" ]; then
    for upd in /data/adb/modules_update/*; do
      [ ! -d "$upd" ] && continue
      mod_id=${upd##*/}
      live="/data/adb/modules/$mod_id"
      echo "  [热合并模块] 正在激活待更新模块: $mod_id"
      rm -rf "$live"
      mv -f "$upd" "$live" 2>/dev/null || {
        mkdir -p "$live"
        cp -af "$upd"/. "$live"/
        rm -rf "$upd"
      }
      rm -f "$live/update"
    done
  fi
}

sanitize_mounts() {
  echo ">>> [MountGuard] 正在扫描 PID 1 全局挂载表与待卸载模块..."

  commit_pending_modules

  for mod_path in /data/adb/modules/*; do
    [ ! -d "$mod_path" ] && continue
    if [ -f "$mod_path/remove" ]; then
      rm_id=${mod_path##*/}
      [ "$rm_id" = "mount_guard" ] && continue
      echo "  [正在彻底卸载模块] 发现 remove 标记: $rm_id"
      pkill -9 -f "/data/adb/modules/$rm_id/" 2>/dev/null
      RM_MNTS=$(awk -v id="$rm_id" '$4 ~ "^/(data/)?adb/modules/" id "/" || $5 ~ "^/data/adb/modules/" id "(/|$)" {print $5}' /proc/1/mountinfo | sort -u)
      for mnt in $RM_MNTS; do
        c=0
        while awk -v id="$rm_id" -v m="$mnt" '($4 ~ "^/(data/)?adb/modules/" id "/" || $5 ~ "^/data/adb/modules/" id "(/|$)") && $5 == m {f=1; exit} END {exit !f}' /proc/1/mountinfo; do
          mount --make-private "$mnt" 2>/dev/null
          umount -l "$mnt" 2>/dev/null || break
          c=$((c + 1))
          [ "$c" -ge 64 ] && break
        done
      done
      [ -f "$mod_path/uninstall.sh" ] && timeout 5 sh "$mod_path/uninstall.sh" >/dev/null 2>&1
      if [ -n "$rm_id" ] && [ "$rm_id" != "modules" ] && [ "$rm_id" != "adb" ]; then
        rm -rf "/data/adb/modules/$rm_id" \
               "/data/adb/modules_update/$rm_id" \
               "/data/adb/$rm_id" \
               "/data/local/tmp/$rm_id"
      fi
      echo "  [已彻底抹除] 模块 ($rm_id) 的挂载、进程与残留目录已全部清空"
    fi
  done

  EXT_SNAP=$(awk '$4 ~ /^\/(data\/)?adb\/modules\// && $5 !~ /^\/data\/adb\// {
    src = $4; if (src ~ /^\/adb\//) src = "/data" src
    mod = src; sub(/^\/data\/adb\/modules\//, "", mod); sub(/\/.*/, "", mod)
    print mod "|" src "|" $5
  }' /proc/1/mountinfo | sort -u)

  SELF_LIST=$(awk '$4 ~ /^\/(data\/)?adb\/modules\// && $5 ~ /^\/data\/adb\// {print $5}' /proc/1/mountinfo | sort -u)
  for mnt in $SELF_LIST; do
    c=0
    while awk -v m="$mnt" '$5 == m {f=1; exit} END {exit !f}' /proc/1/mountinfo; do
      mount --make-private "$mnt" 2>/dev/null
      umount -l "$mnt" 2>/dev/null || break
      c=$((c + 1))
      [ "$c" -ge 64 ] && break
    done
    echo "  [已清除泄漏] 剥离 $c 层自挂载: $mnt"
  done

  echo "$EXT_SNAP" | while IFS='|' read -r mod src dst; do
    [ -z "$dst" ] && continue
    MOD_DIR="/data/adb/modules/$mod"
    if [ ! -d "$MOD_DIR" ] || [ -f "$MOD_DIR/disable" ]; then
      while awk -v m="$dst" '$4 ~ /^\/(data\/)?adb\/modules\// && $5 == m {f=1; exit} END {exit !f}' /proc/1/mountinfo; do
        mount --make-private "$dst" 2>/dev/null
        umount -l "$dst" 2>/dev/null || break
      done
      echo "  [已卸载残留] 清理已禁用/不存在模块 ($mod) 的挂载: $dst"
    else
      cur=$(awk -v m="$dst" '$4 ~ /^\/(data\/)?adb\/modules\// && $5 == m {c++} END {print c+0}' /proc/1/mountinfo)
      if [ "$cur" -gt 1 ]; then
        drop=0
        while [ "$(awk -v m="$dst" '$4 ~ /^\/(data\/)?adb\/modules\// && $5 == m {c++} END {print c+0}' /proc/1/mountinfo)" -gt 1 ]; do
          mount --make-private "$dst" 2>/dev/null
          umount -l "$dst" 2>/dev/null || break
          drop=$((drop + 1))
          [ "$drop" -ge 64 ] && break
        done
        echo "  [已折叠堆叠] 模块 ($mod) 剥离 $drop 层冗余挂载: $dst"
      elif [ "$cur" -eq 0 ] && [ -e "$src" ]; then
        mount --bind "$src" "$dst" 2>/dev/null
        echo "  [已恢复单层] 重新挂载 ($mod): $dst"
      fi
      mount --make-private "$dst" 2>/dev/null
    fi
  done

  LEAK_CNT=$(awk '$4 ~ /^\/(data\/)?adb\/modules\// && $5 ~ /^\/data\/adb\// {c++} END {print c+0}' /proc/1/mountinfo)
  SHARED_CNT=$(awk '$4 ~ /^\/(data\/)?adb\/modules\// && $0 ~ /shared:/ {c++} END {print c+0}' /proc/1/mountinfo)
  echo ">>> [MountGuard] 扫描完毕: /data/adb 泄漏数=$LEAK_CNT, 未隔离 shared 隐患数=$SHARED_CNT"
}
