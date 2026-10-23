#!/usr/bin/env bash
# ============================================================
# NapCat 登录成功之后运行：把反向 WS 指向 AstrBot
# 用法： bash configure-napcat.sh
# ============================================================
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/qqbot}"
OB_PORT="${OB_PORT:-6199}"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

TOKEN="$(cat "$APP_DIR/.ob_token" 2>/dev/null || true)"
[[ -n "$TOKEN" ]] || die "读不到 $APP_DIR/.ob_token，请确认数据已迁移"

say "定位 NapCat 配置目录"
CFG_DIR="$(find "$HOME/Napcat" -type d -name config -path "*napcat*" 2>/dev/null | head -1)"
[[ -n "$CFG_DIR" ]] || die "没找到 NapCat 配置目录（QQ 是否已登录过？先运行 napcat 并扫码）"
echo "  $CFG_DIR"

CONF="$(ls -t "$CFG_DIR"/onebot11_*.json 2>/dev/null | head -1)"
[[ -n "$CONF" ]] || die "没找到 onebot11_*.json，请先完成 QQ 登录"
echo "  目标配置: $CONF"

say "备份并写入反向 WS 配置"
cp "$CONF" "$CONF.bak.$(date +%s)"

python3 - "$CONF" "$TOKEN" "$OB_PORT" <<'PY'
import json, sys
path, token, port = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = json.load(open(path))
net = cfg.setdefault("network", {})
clients = [c for c in net.get("websocketClients", []) if c.get("name") != "astrbot"]
clients.append({
    "enable": True,
    "name": "astrbot",
    "url": f"ws://127.0.0.1:{port}/ws",
    "reportSelfMessage": False,
    "messagePostFormat": "array",
    "token": token,
    "debug": False,
    "heartInterval": 30000,
    "reconnectInterval": 30000,
    "verifyCertificate": True,
})
net["websocketClients"] = clients
json.dump(cfg, open(path, "w"), ensure_ascii=False, indent=2)
print("  已写入 websocketClients:", c["url"])
PY

say "重启 NapCat 使配置生效"
napcat restart || napcat start || true

sleep 8
say "核对连接"
if ss -tnp 2>/dev/null | grep -q ":$OB_PORT"; then
  echo "  ✔ 已有到 $OB_PORT 的连接"
else
  echo "  ✘ 暂未检测到连接，请稍等 30 秒后检查："
  echo "     ss -tnp | grep $OB_PORT"
  echo "     journalctl -u astrbot -n 30"
fi

echo
echo "AstrBot 侧确认（应出现「适配器已连接」）："
tail -20 "$APP_DIR/logs/astrbot.out" 2>/dev/null | grep -a "适配器已连接" || \
  echo "  还没有，等 NapCat 重连后自动出现（重连间隔 30 秒）"
