# Linux 一键部署脚本

面向 **Ubuntu 22.04/24.04、Debian 12**（amd64 / arm64），三个脚本按顺序执行即可从零部署到可用。

> 适用于无图形界面的服务器 / 虚拟机。QQ 通过 Xvfb 无头运行，不需要桌面环境。

## 前置条件

- 一台能上网的 Linux（建议 2 核 / 4 GB 起）
- 有 `sudo` 权限的用户
- 一个 **QQ 小号**（不要用主号）

## 执行顺序

```bash
# 1. 部署 AstrBot（可选恢复已有数据）
sudo APP_USER=$USER bash install-linux.sh

# 2. 安装 NapCat（QQ Linux 客户端 + Xvfb + 管理 CLI）
bash install-napcat.sh

# 3. 启动并扫码登录
napcat
#    日志会输出二维码图片路径，或 NapCat WebUI 地址（默认 6099）
#    手机 QQ 扫码后，务必在手机上点「确认登录」

# 4. 登录成功后，把反向 WS 指向 AstrBot
bash configure-napcat.sh
```

## 每一步做什么

| 脚本 | 内容 |
|---|---|
| `install-linux.sh` | 装系统依赖 → 建 venv → `pip install astrbot` → 恢复数据 → 写 systemd 服务 → 启动 |
| `install-napcat.sh` | 调 NapCat 官方一键脚本，`--docker n`（不走 Docker Hub） |
| `configure-napcat.sh` | 找到 `onebot11_*.json`，写入反向 WS 客户端配置，重启并核对连接 |

## 可调参数

通过环境变量覆盖，例如：

```bash
sudo APP_DIR=/srv/qqbot APP_USER=bot APP_PORT=6199 bash install-linux.sh
```

| 变量 | 默认值 | 说明 |
|---|---|---|
| `APP_DIR` | `/opt/qqbot` | 安装目录 |
| `APP_USER` | 当前 sudo 用户 | 服务运行用户 |
| `OB_PORT` | `6199` | OneBot 反向 WS 端口 |
| `WEB_PORT` | `6185` | AstrBot WebUI 端口 |
| `PIP_INDEX` | 清华源 | PyPI 镜像 |
| `NAPCAT_PROXY` | `0`（直连） | GitHub 加速前缀，如 `https://ghproxy.net/` |

## 迁移已有数据

把打包好的 `qqbot-data.tar.gz` 放到 `/tmp/`，`install-linux.sh` 会自动解包到 `$APP_DIR`。

数据包应包含：`data/`（配置、会话库、技能）、`.ob_token`、`.dashpw`。

> ⚠️ 数据包里有 **DeepSeek API Key 和 WebUI 密码**，不要提交到任何仓库。

## 注意事项

1. **QQ 登录态无法跨机器迁移**，必须重新扫码。
2. **同一个 QQ 号不能同时在两处登录**，切换前先退出旧的。
3. 所有端口默认只绑 `127.0.0.1`。需要远程访问请用 SSH 隧道：
   ```bash
   ssh -L 6185:127.0.0.1:6185 用户@服务器
   ```

## 验收

```bash
systemctl is-active astrbot                                  # active
ss -lnt | grep -E '6185|6199|6099'                           # 三个端口都在
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:6185/   # 200
grep '适配器已连接' /opt/qqbot/logs/astrbot.out | tail -1     # 有输出
```

## 卸载

```bash
sudo systemctl disable --now astrbot
sudo rm -f /etc/systemd/system/astrbot.service
sudo rm -rf /opt/qqbot
# NapCat 数据在 ~/Napcat，如需清理：rm -rf ~/Napcat
```
