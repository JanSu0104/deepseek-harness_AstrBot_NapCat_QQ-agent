#!/bin/bash
# 停止 AstrBot。若由 launchd 托管，必须 bootout，否则会被 KeepAlive 立刻拉起。
cd "$(dirname "$0")"

LABEL="com.qqbot.astrbot"
UID_NUM="$(id -u)"

if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
  echo "AstrBot 由 launchd 托管，正在卸载服务..."
  launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
  sleep 2
  if ! lsof -nP -iTCP:6185 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "已停止（下次运行 ./start.sh 可重新启动）。"
    exit 0
  fi
fi

PIDS=$(lsof -nP -iTCP:6185 -sTCP:LISTEN -t 2>/dev/null || true)

if [ -z "$PIDS" ]; then
  echo "AstrBot 未在运行。"
  exit 0
fi

echo "停止进程: $PIDS"
kill $PIDS 2>/dev/null || true

for i in $(seq 1 10); do
  if ! lsof -nP -iTCP:6185 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "已停止。"
    exit 0
  fi
  sleep 1
done

echo "仍未退出，强制结束。"
kill -9 $PIDS 2>/dev/null || true
