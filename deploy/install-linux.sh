#!/usr/bin/env bash
# ============================================================
# AstrBot + NapCat 迁移到 Linux 的自动化部署脚本
# 目标系统：Ubuntu 22.04/24.04 或 Debian 12（amd64 / arm64）
# 用法：  sudo bash install-linux.sh
# ============================================================
set -euo pipefail

# ---------- 可调参数 ----------
APP_DIR="${APP_DIR:-/opt/qqbot}"          # 安装目录
APP_USER="${APP_USER:-$SUDO_USER}"        # 运行服务的用户（默认当前sudo用户）
PIP_INDEX="${PIP_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"
OB_PORT="${OB_PORT:-6199}"                # AstrBot OneBot 反向WS端口
WEB_PORT="${WEB_PORT:-6185}"              # AstrBot WebUI端口
NAPCAT_PROXY="${NAPCAT_PROXY:-0}"         # NapCat 安装器 GitHub 代理，0=直连
# ------------------------------

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "请用 sudo 运行"
[[ -n "${APP_USER:-}" ]] || die "无法确定运行用户，请显式指定：APP_USER=你的用户名 sudo -E bash $0"

say "环境检查"
. /etc/os-release
echo "  系统: $PRETTY_NAME  ($(uname -m))"
echo "  用户: $APP_USER"
echo "  目录: $APP_DIR"
command -v apt-get >/dev/null || die "本脚本仅支持 apt 系发行版"

say "安装系统依赖"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  python3 python3-venv python3-pip \
  git curl wget unzip xz-utils ca-certificates \
  sqlite3 \
  fonts-noto-cjk fontconfig \
  libgl1 libglib2.0-0 libnss3 libxss1 libasound2t64 2>/dev/null \
  || apt-get install -y -qq libasound2 2>/dev/null || true

# 确认 Python 版本 >= 3.12（AstrBot 4.x 要求）
PY=python3
PYV=$($PY -c 'import sys;print("%d.%d"%sys.version_info[:2])')
echo "  Python: $PYV"
if ! $PY -c 'import sys;sys.exit(0 if sys.version_info>=(3,12) else 1)'; then
  echo "  当前 Python 低于 3.12，尝试安装 python3.12 ..."
  apt-get install -y -qq python3.12 python3.12-venv python3.12-dev || true
  command -v python3.12 >/dev/null && PY=python3.12 || die "系统 Python 版本不足 3.12，请升级发行版"
fi

say "创建目录"
mkdir -p "$APP_DIR"/{data,logs}
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

say "部署 AstrBot"
if [[ -d "$APP_DIR/.venv" ]]; then
  echo "  已存在 venv，跳过创建"
else
  sudo -u "$APP_USER" "$PY" -m venv "$APP_DIR/.venv"
fi
sudo -u "$APP_USER" "$APP_DIR/.venv/bin/pip" install -q --upgrade pip -i "$PIP_INDEX"
say "安装 AstrBot（依赖较多，约 2-5 分钟）"
sudo -u "$APP_USER" "$APP_DIR/.venv/bin/pip" install -q astrbot -i "$PIP_INDEX"
sudo -u "$APP_USER" "$APP_DIR/.venv/bin/astrbot" --version || true

say "恢复数据（若迁移包存在）"
if [[ -f /tmp/qqbot-data.tar.gz ]]; then
  sudo -u "$APP_USER" tar xzf /tmp/qqbot-data.tar.gz -C "$APP_DIR"
  echo "  已解包 /tmp/qqbot-data.tar.gz"
else
  echo "  未找到 /tmp/qqbot-data.tar.gz，将使用全新配置"
fi

say "写入 systemd 服务：astrbot.service"
cat >/etc/systemd/system/astrbot.service <<EOF
[Unit]
Description=AstrBot QQ Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/.venv/bin/astrbot run
Restart=always
RestartSec=10
StandardOutput=append:$APP_DIR/logs/astrbot.out
StandardError=append:$APP_DIR/logs/astrbot.err
Environment=LANG=zh_CN.UTF-8
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable astrbot.service
systemctl restart astrbot.service

say "等待 AstrBot 就绪"
for i in $(seq 1 45); do
  if ss -lnt 2>/dev/null | grep -q ":$WEB_PORT "; then
    echo "  WebUI 已监听 $WEB_PORT"
    break
  fi
  sleep 2
done
ss -lnt | grep -E ":($WEB_PORT|$OB_PORT) " || echo "  注意：端口未全部监听，请查看 journalctl -u astrbot -n 50"

cat <<EOF

\033[1;32m============================================================
AstrBot 部署完成
============================================================\033[0m
  目录      : $APP_DIR
  WebUI     : http://127.0.0.1:$WEB_PORT
  反向WS    : ws://127.0.0.1:$OB_PORT/ws
  服务管理  : systemctl {status|restart|stop} astrbot
  日志      : tail -f $APP_DIR/logs/astrbot.out
  WebUI 密码: cat $APP_DIR/.dashpw  （若随数据迁移过来）
  OneBot令牌: cat $APP_DIR/.ob_token

下一步：安装 NapCat（需要 QQ 登录扫码）
  bash $(cd "$(dirname "$0")" && pwd)/install-napcat.sh

EOF
