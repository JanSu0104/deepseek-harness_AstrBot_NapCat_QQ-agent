#!/bin/bash
# 以 NapCat 模式启动 QQ
# 关键：必须带 --no-sandbox 参数，否则 loadNapCat.js 会走原版 QQ 分支，机器人收不到消息
cd "$(dirname "$0")"

if pgrep -f "MacOS/QQ --no-sandbox" >/dev/null 2>&1; then
  echo "QQ 已经以 NapCat 模式在运行了（PID: $(pgrep -f 'MacOS/QQ --no-sandbox' | head -1)）"
  exit 0
fi

if pgrep -f "/Applications/QQ.app/Contents/MacOS/QQ" >/dev/null 2>&1; then
  echo "检测到 QQ 正在以【原版】模式运行（没有 --no-sandbox）。"
  echo "原版模式下 NapCat 不会加载，机器人收不到消息。"
  echo
  read -r -p "要退出原版 QQ 并以 NapCat 模式重启吗？[y/N] " ans
  case "$ans" in
    y|Y) pkill -f "/Applications/QQ.app/Contents/MacOS/QQ" ; sleep 3 ;;
    *) echo "已取消。"; exit 0 ;;
  esac
fi

echo "正在以 NapCat 模式启动 QQ..."
nohup /Applications/QQ.app/Contents/MacOS/QQ --no-sandbox > /tmp/qq-napcat.log 2>&1 &
echo "已启动。等待 NapCat 就绪..."

for i in $(seq 1 30); do
  if lsof -nP -iTCP:6099 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "NapCat 就绪（WebUI 端口 6099）。"
    echo "若需要重新登录，运行 ./status.sh 里的提示，或直接看 NapCat WebUI。"
    exit 0
  fi
  sleep 1
done

echo "30 秒内未就绪，可能是 QQ 需要重新扫码登录，或注入出错。"
echo "日志：/tmp/qq-napcat.log"
