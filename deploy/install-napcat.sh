#!/usr/bin/env bash
# ============================================================
# 在 Linux 上安装 NapCat（QQ 协议端）
# 依赖：已跑过 install-linux.sh
# 用法： bash install-napcat.sh
# ============================================================
set -euo pipefail

NAPCAT_PROXY="${NAPCAT_PROXY:-0}"   # 0=直连；国内不通时填代理前缀，如 https://ghproxy.net/
OB_PORT="${OB_PORT:-6199}"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

say "安装 NapCat（官方一键脚本，含 QQ Linux 客户端 + Xvfb 无头运行）"
cd "$HOME"
curl -fL --connect-timeout 20 --max-time 1800 \
  -o napcat.sh https://raw.githubusercontent.com/NapNeko/NapCat-Installer/main/script/install.sh

# --docker n : 不用 Docker（Docker Hub 当前不可达）
# --cli y    : 同时安装管理 CLI
# --github-proxy: 0 表示直连
bash napcat.sh --docker n --cli y --github-proxy "$NAPCAT_PROXY"

cat <<EOF

\033[1;33m============================================================
NapCat 安装完成，下一步需要登录 QQ
============================================================\033[0m

1) 启动：        napcat
2) 首次运行会输出：二维码图片路径 或 NapCat WebUI 地址（默认 6099）
3) 用手机 QQ 扫码并在手机上点「确认登录」
4) 登录成功后，运行本目录下的：
       bash configure-napcat.sh
   把反向 WS 指向 AstrBot，并自动核对 token。

提示：
  · NapCat 数据目录：~/Napcat
  · 查看状态：       napcat status
  · 重启：           napcat restart

EOF
