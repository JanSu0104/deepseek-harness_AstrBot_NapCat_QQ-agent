#!/bin/bash
# 启动 AstrBot：优先用 launchd 托管（开机自启 + 崩溃自动拉起），否则退回 nohup
set -e
cd "$(dirname "$0")"

LABEL="com.qqbot.astrbot"
UID_NUM="$(id -u)"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

if lsof -nP -iTCP:6185 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "AstrBot 已在运行（6185 已监听）。用 ./status.sh 查看。"
  exit 0
fi

mkdir -p logs

if [ -f "$PLIST_DST" ]; then
  echo "通过 launchd 启动..."
  launchctl bootstrap "gui/$UID_NUM" "$PLIST_DST" 2>/dev/null \
    || launchctl kickstart -k "gui/$UID_NUM/$LABEL" 2>/dev/null \
    || true
else
  echo "未安装 launchd 服务，使用后台进程启动..."
  nohup ./.venv/bin/astrbot run >> logs/astrbot.out 2>&1 &
  echo "PID=$!"
fi

echo "等待 WebUI 就绪..."
for i in $(seq 1 40); do
  if lsof -nP -iTCP:6185 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "就绪：http://localhost:6185"
    echo "日志：tail -f $(pwd)/logs/astrbot.out"
    exit 0
  fi
  sleep 1
done

echo "40 秒内未就绪，请查看 logs/astrbot.out 与 logs/astrbot.err"
exit 1
