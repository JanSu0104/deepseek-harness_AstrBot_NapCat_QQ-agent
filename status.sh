#!/bin/bash
# 查看 AstrBot / OneBot / NapCat 的运行状态
cd "$(dirname "$0")"

LABEL="com.qqbot.astrbot"
UID_NUM="$(id -u)"

echo "===== launchd 托管 ====="
if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
  state=$(launchctl print "gui/$UID_NUM/$LABEL" 2>/dev/null | awk '/state = /{print $3; exit}')
  pid=$(launchctl print "gui/$UID_NUM/$LABEL" 2>/dev/null | awk '/pid = /{print $3; exit}')
  echo "  已托管（state=${state:-?} pid=${pid:-无}） · 崩溃会自动重启 · 开机自启"
else
  echo "  未托管（可用 ./start.sh 安装启动，或手动 nohup 方式运行）"
fi

echo
echo "===== 端口 ====="
for p in 6185 6199 6099; do
  line=$(lsof -nP -iTCP:$p -sTCP:LISTEN 2>/dev/null | tail -n +2 | head -1)
  if [ -n "$line" ]; then
    echo "  $p  监听中  ->  $(echo "$line" | awk '{print $1" pid="$2" "$9}')"
  else
    echo "  $p  未监听"
  fi
done

echo
echo "===== QQ 启动模式 ====="
if pgrep -f "MacOS/QQ --no-sandbox" >/dev/null 2>&1; then
  echo "  NapCat 模式（正确，机器人可用）"
elif pgrep -f "/Applications/QQ.app/Contents/MacOS/QQ" >/dev/null 2>&1; then
  echo "  原版模式（NapCat 未加载，机器人收不到消息）→ 运行 ./start-qq.command"
else
  echo "  QQ 未运行 → 运行 ./start-qq.command"
fi

echo
echo "===== AstrBot WebUI ====="
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:6185/ 2>/dev/null || echo 000)
echo "  http://localhost:6185  -> HTTP $code"

echo
echo "===== OneBot 适配器日志 ====="
grep -a "适配器已连接\|aiocqhttp" logs/astrbot.out 2>/dev/null | tail -2 || echo "  (无日志)"

echo
echo "===== 最近日志 ====="
tail -4 logs/astrbot.out 2>/dev/null || echo "  (没有 logs/astrbot.out)"
