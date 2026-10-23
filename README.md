# 用 DeepSeek Harness + AstrBot + NapCat 搭建 QQ 机器人

> 一份从零到可用的实战教程。所有命令、坑点均来自真实部署过程（macOS 26 / Apple Silicon），
> Windows 与 Linux 的差异在对应章节单独标注。

---

## 目录

**省流：** [快速开始](#快速开始) · [仓库内容](#仓库内容)

1. [先搞清楚三个组件各干什么](#一先搞清楚三个组件各干什么)
2. [环境要求](#二环境要求)
3. [阶段一：用 DeepSeek Harness 做环境勘察](#三阶段一用-deepseek-harness-做环境勘察)
4. [阶段二：部署 AstrBot](#四阶段二部署-astrbot)
5. [阶段三：安装 NapCat](#五阶段三安装-napcat)
6. [阶段四：登录 QQ](#六阶段四登录-qq)
7. [阶段五：把 NapCat 接到 AstrBot](#七阶段五把-napcat-接到-astrbot)
8. [阶段六：接入大模型](#八阶段六接入大模型)
9. [阶段七：验证](#九阶段七验证)
10. [阶段八：托管与自启](#十阶段八托管与自启)
11. [常见坑（实战踩过的）](#十一常见坑实战踩过的)
12. [安全与合规](#十二安全与合规)
13. [附录](#十三附录)

---

## 快速开始

不想读全文，直接抄：

```bash
# 1. 装 AstrBot
mkdir -p ~/qqbot && cd ~/qqbot
python3 -m venv .venv && ./.venv/bin/pip install astrbot
./.venv/bin/astrbot init -y && ./.venv/bin/astrbot run   # 首次启动生成配置，Ctrl+C 停掉

# 2. 装 NapCat（macOS 用安装器；Linux 用 deploy/ 脚本）
#    macOS: https://github.com/NapNeko/NapCat-Mac-Installer/releases/latest

# 3. 配置 data/cmd_config.json 的 platform 段（见第七节），重启 AstrBot

# 4. NapCat WebUI → 网络配置 → 新建 WebSocket 客户端
#    URL:   ws://127.0.0.1:6199/ws
#    Token: 同第 3 步里填的 ws_reverse_token

# 5. AstrBot WebUI(6185) → 服务提供商 → 填 DeepSeek API Key
```

看到日志出现 `aiocqhttp(OneBot v11) 适配器已连接。` 就成功了。

**Linux 用户**可以直接用 [`deploy/`](deploy/) 里的三个脚本，一条命令装完。

---

## 仓库内容

| 文件 / 目录 | 说明 |
|---|---|
| `README.md` | 本教程 |
| `start.sh` / `stop.sh` / `status.sh` | macOS 运行时脚本：启动、停止、体检 |
| `start-qq.command` | macOS 专用：以 NapCat 模式启动 QQ（必须带 `--no-sandbox`） |
| `deploy/` | Linux 一键部署脚本（AstrBot + NapCat + systemd） |
| `LICENSE` | MIT |

> 根目录的四个脚本是 **macOS 版运行时工具**，复制到你自己的部署目录（与 `.venv`、`data/` 同级）后使用。
> Linux 用户请用 [`deploy/`](deploy/)，或参考[第十节](#十阶段八托管与自启)的 systemd 配置。

### 克隆后怎么用

```bash
git clone <本仓库>

# macOS：复制运行时脚本到部署目录
cp <本仓库>/*.sh <本仓库>/*.command ~/qqbot/
cd ~/qqbot && ./start.sh

# Linux：直接跑部署脚本
cd <本仓库>/deploy && sudo APP_USER=$USER bash install-linux.sh
```

---

## 一、先搞清楚三个组件各干什么

```
┌──────────┐   OneBot v11    ┌──────────┐    扫码登录   ┌────────┐
│ AstrBot  │◄───reverse WS───│  NapCat  │◄──────────────│ QQ App │
└────┬─────┘                 └──────────┘               └────────┘
     │ HTTPS
     ▼
  ┌──────────────┐
  │ DeepSeek API │  ← 机器人真正的"大脑"
  └──────────────┘
```

> 部署与排障环节由 **DeepSeek Harness** 完成 —— 它是"施工方"，不参与上面这条消息链路。

### 三个组件，三种角色

| 组件 | 角色 | 一句话解释 |
|---|---|---|
| **NapCat** | 协议端 | 黑进 QQ 客户端，把 QQ 变成能收发消息的机器人。非官方，有风控风险 |
| **AstrBot** | 机器人框架 | 决定"收到这条消息该干什么"：调模型、跑插件、管会话 |
| **DeepSeek Harness** | 部署/运维代理 | 帮你装环境、写配置、查日志、修故障的 AI 工程师 |

> ⚠️ **一个重要澄清**：DeepSeek Harness **不是**机器人的模型后端。
> 它不参与 QQ 消息链路，也不提供 OpenAI 兼容接口。机器人对话用的是 **DeepSeek API**
> （在 AstrBot 的「服务提供商」里填 API Key）。Harness 的价值在于：把几十条命令、
> 十几个配置项、跨平台差异这些容易出错的活，交给它自动完成并自检。

---

## 二、环境要求

### 硬件与系统

| 项 | 最低 | 建议 |
|---|---|---|
| 内存 | 4 GB | 8 GB（QQ 本身是 Electron 应用，很吃内存） |
| 磁盘 | 5 GB | 10 GB |
| 系统 | macOS 12+ / Windows 10+ / Linux（Debian/Ubuntu 系） | 同左 |

### 软件依赖

- **Python 3.12+**（AstrBot 4.x 硬性要求）
- **能访问**：PyPI、GitHub（国内可能需要代理）
- **一个 QQ 小号**（强烈建议，不要用主号）
- **DeepSeek API Key**（或其他 OpenAI 兼容服务）

### 网络预检

部署前先跑一遍，确认关键站点可达：

```bash
for u in https://pypi.org https://github.com https://raw.githubusercontent.com; do
  printf "%-45s " "$u"; curl -s -o /dev/null -w "%{http_code}\n" --max-time 8 "$u"
done
```

出现 `000` 表示超时不通，需要配代理或换镜像源。

---

## 三、阶段一：用 DeepSeek Harness 做环境勘察

**不要上来就装。** 先让 Harness 把环境摸清楚，避免装了半截才发现 Python 版本不对、
GitHub 不通、端口被占。

### 提示词模板（可直接复制）

```
帮我在这台机器上部署 AstrBot + NapCat 的 QQ 机器人。先别动手，
做一次环境勘察并汇报：
1. 操作系统、架构、内存、磁盘剩余
2. Python 版本（AstrBot 4.x 需要 3.12+）
3. 是否已装 Docker、Node、Git
4. PyPI / GitHub / raw.githubusercontent 是否可达（逐个测 HTTP 状态码）
5. 6185 / 6199 / 6099 端口是否被占用
6. 是否已安装 QQ 客户端、版本号多少

汇报完等我确认再开始装。
```

### 为什么这步重要

真实案例中，勘察阶段就发现了三个会导致后续失败的问题：

- `github.com` 返回 `000`（被墙）→ 后续所有 GitHub 下载都要走代理
- 没装 Docker → 不能用官方推荐的 compose 方案，必须原生安装
- 已装 QQ 但它是 **App Store 版**（`isMas: true`）→ 影响 NapCat 注入方式

**这些问题在装到一半才发现，返工成本极高。**

---

## 四、阶段二：部署 AstrBot

### 4.1 建独立环境

不要装到系统 Python 里，用 venv 隔离：

```bash
mkdir -p ~/qqbot && cd ~/qqbot
python3 -m venv .venv
./.venv/bin/python -m pip install --upgrade pip
```

### 4.2 安装

```bash
./.venv/bin/python -m pip install astrbot
```

> 国内加速：追加 `-i https://pypi.tuna.tsinghua.edu.cn/simple`
> 依赖有 60+ 个，首次安装约 2-5 分钟。

### 4.3 初始化

```bash
./.venv/bin/astrbot init -y
```

会创建 `data/` 目录结构。**配置文件 `data/cmd_config.json` 此时还不存在**，
要等首次启动才生成。

### 4.4 首次启动（生成配置）

```bash
./.venv/bin/astrbot run
```

看到这几行就算成功：

```
AstrBot v4.29.1 WebUI is ready
 ➜  Local: http://localhost:6185
 ➜  Username: astrbot
```

按 `Ctrl+C` 停掉，接下来改配置。
（首次启动会打印一个随机 WebUI 密码，记下来；或者用下面的命令重设。）

### 4.5 设置 WebUI 密码

```bash
./.venv/bin/astrbot password --username astrbot
```

按提示输入两遍新密码。

---

## 五、阶段三：安装 NapCat

NapCat 的原理是**改写 QQ 客户端的加载入口**，所以必须先有 QQ。

### macOS

1. 安装 QQ 到 `/Applications/QQ.app`（**App Store 版也可以**，官方推荐）
2. 下载 [NapCat-Mac-Installer](https://github.com/NapNeko/NapCat-Mac-Installer/releases/latest)
3. 打开安装器 → 点「安装」→ 输入**开机密码**（它要改 QQ.app 内的 `package.json`）
4. 安装完成后选「切换程序入口 NapCat」

> 如果系统提示无权修改：「系统设置 → 隐私与安全性 → App 管理」里允许 `NapCatInstaller`。

### Windows

1. 安装 QQ
2. 下载 `NapCat.Shell.Windows.OneKey.zip`，解压运行 `NapCatInstaller.exe`
3. 完成

### Linux（无头服务器推荐）

```bash
curl -fL --connect-timeout 20 --max-time 1800 \
  -o napcat.sh https://raw.githubusercontent.com/NapNeko/NapCat-Installer/main/script/install.sh
bash napcat.sh --docker n --cli y --github-proxy 0
```

> `--docker n` 表示不用 Docker（Docker Hub 在国内常不可达）。
> 安装后 QQ 由 Xvfb 无头运行，不需要图形界面。

---

## 六、阶段四：登录 QQ

### 关键认知：macOS 上不会有登录窗口

这是最容易卡住的地方。NapCat 在 macOS 上是**无窗口后台运行**的，
QQ 的登录界面不会弹出来。二维码以图片形式存在：

```
~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/NapCat/cache/qrcode.png
```

或者在 NapCat 的 WebUI 里扫码：

```
http://127.0.0.1:6099/webui
```

（WebUI 的 token 在 `.../NapCat/config/webui.json` 里。）

### 登录步骤

1. 打开 WebUI（或直接看上面那个 png）
2. 手机 QQ → 右上角 `+` → 扫一扫
3. **手机上必须点「确认登录」** ← 只扫码不确认，NapCat 会一直停在等待状态

### 怎么判断登录成功

| 现象 | 含义 |
|---|---|
| 二维码图片不再刷新（`mtime` 停在某刻） | ✅ 登录成功 |
| `config/onebot11_<QQ号>.json` 出现 | ✅ 登录成功 |
| 二维码每隔约 1 分钟变一次 | ❌ 仍在等待扫码 |

> 二维码约 1 分钟过期一次。如果扫码来不及，直接在 WebUI 页面里扫（它会自动刷新）。

---

## 七、阶段五：把 NapCat 接到 AstrBot

### 7.1 先配置 AstrBot 这一端

编辑 `data/cmd_config.json`，在 `platform` 数组里加：

```json
{
  "id": "napcat",
  "type": "aiocqhttp",
  "enable": true,
  "ws_reverse_host": "127.0.0.1",
  "ws_reverse_port": 6199,
  "ws_reverse_token": "自己生成一个随机字符串"
}
```

> **为什么用 `127.0.0.1` 而不是 `0.0.0.0`？**
> 两个原因：① 不把机器人端口暴露到局域网/公共 WiFi；② NapCat 和 AstrBot 在同一台机器，
> 走回环就行，**换网络、断网都不用重配**。

### 7.2 再配置 NapCat 这一端

NapCat WebUI → 网络配置 → 新建 → **WebSocket 客户端**：

| 字段 | 值 |
|---|---|
| 名称 | `astrbot` |
| URL | `ws://127.0.0.1:6199/ws` |
| Token | 与上面 `ws_reverse_token` **完全一致** |
| 心跳间隔 | `30000` |
| 重连间隔 | `30000` |
| 启用 | ✅ |

> 路径 `/ws` 不能少，少了会 404。

### 7.3 最容易踩的坑：token 的传递方式

AstrBot 的 aiocqhttp 适配器校验 token 时，**只认 HTTP 头**：

```
Authorization: Bearer <token>
```

它**不认** URL 查询参数 `?access_token=xxx`。自己写脚本模拟客户端时，
如果只放 query 参数，会收到 `HTTP 401`。

NapCat 的图形界面会自动处理好这一点，你手动填 Token 即可。

### 7.4 确认连接成功

AstrBot 日志里出现：

```
aiocqhttp(OneBot v11) 适配器已连接。
```

或者查连接：

```bash
lsof -nP -iTCP:6199 | grep ESTABLISHED
```

能看到 `QQ Helper ↔ Python` 的一对连接就对了。

---

## 八、阶段六：接入大模型

打开 `http://localhost:6185` → 左侧「服务提供商」→ 新增：

| 服务商 | Base URL | 备注 |
|---|---|---|
| DeepSeek | `https://api.deepseek.com/v1` | 便宜、中文好，推荐 |
| 硅基流动 | `https://api.siliconflow.cn/v1` | 有免费额度 |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | 阿里云 |
| OpenAI | `https://api.openai.com/v1` | 需要外币卡 |

填好 API Key，保存。然后到「机器人」页把默认模型指向它。

> **不配模型会怎样？** 机器人能收到消息，但不会回复。日志里会出现
> `未找到任何对话模型（提供商），跳过 LLM 请求处理。`

### 必做的一项：设置管理员

`data/cmd_config.json` 里的 `admins_id` 默认是占位值 `["astrbot"]`，
这意味着**你的 QQ 号不是管理员**，`/reset`、`/provider`、`/stop` 这类指令会毫无反应。

改成你自己的 QQ 号：

```json
"admins_id": ["你的QQ号"]
```

改完重启 AstrBot。

---

## 九、阶段七：验证

### 9.1 基础连通性

```bash
# WebUI
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:6185/     # 200

# 端口
lsof -nP -iTCP -sTCP:LISTEN | grep -E '6185|6199|6099'

# 适配器
grep "适配器已连接" logs/astrbot.out | tail -1
```

### 9.2 端到端测试

**标准做法**：用你的 QQ 给机器人发一条私聊消息，几秒内应该收到回复。

**进阶做法**（在 QQ 登录之前就能验证链路）：
写一个模拟 NapCat 的 WebSocket 客户端，连上 6199 发一条伪造事件，看 AstrBot 是否会
回推 `send_private_msg` action。这能证明"事件处理 → 回复生成"整条链路是通的，
只剩 QQ 这一环没接。

### 9.3 让 Harness 帮你验证

```
我现在的配置是：AstrBot 在 6185/6199，NapCat 在 6099。
请帮我做一次完整体检：
1. 三个端口是否都在监听，绑定地址分别是什么
2. token 在两侧是否一致
3. 适配器是否已连接、连接对是否 ESTABLISHED
4. 启动后日志里有没有 ERROR / Traceback
5. 管理员 ID、大模型配置是否符合预期
6. 有没有把端口暴露到 0.0.0.0 的安全隐患
```

---

## 十、阶段八：托管与自启

### macOS：launchd

```xml
<!-- ~/Library/LaunchAgents/com.qqbot.astrbot.plist -->
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ThrottleInterval</key><integer>20</integer>
```

**两个 macOS 特有的坑**：

1. **`~/Documents` 受隐私保护**，launchd 打不开里面的日志文件，会报
   `exit code 78: EX_CONFIG`。日志路径要放到 `/tmp` 或 `~/Library/Logs`。
2. **`stop.sh` 必须用 `launchctl bootout`**，直接 `kill` 会被 `KeepAlive` 立刻拉起。

### Linux：systemd

```ini
[Unit]
Description=AstrBot QQ Bot
After=network-online.target

[Service]
Type=simple
User=你的用户
WorkingDirectory=/opt/qqbot
ExecStart=/opt/qqbot/.venv/bin/astrbot run
Restart=always
RestartSec=10
StandardOutput=append:/opt/qqbot/logs/astrbot.out
StandardError=append:/opt/qqbot/logs/astrbot.err

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now astrbot
```

### ⚠️ 一个隐藏很深的问题：直接点 QQ 图标 = 机器人静默失联

NapCat 的加载器逻辑是：

```js
const loadNapcat = process.argv.includes('--no-sandbox');
```

**只有带 `--no-sandbox` 参数启动才会加载 NapCat。**

- ✅ 用安装器里的「启动」按钮，或自己写脚本：`/Applications/QQ.app/Contents/MacOS/QQ --no-sandbox`
- ❌ 直接点 Dock 图标 → 走原版 QQ 分支 → NapCat 不加载 → 机器人收不到消息

表面看 QQ 一切正常，实际机器人已经"死"了，极难排查。
建议做一个 `start-qq.command` 脚本专门负责正确启动。

---

## 十一、常见坑（实战踩过的）

| 现象 | 根因 | 解法 |
|---|---|---|
| 看不到 QQ 登录窗口 | macOS 上 NapCat 无头运行，本来就没有窗口 | 去 `NapCat/cache/qrcode.png` 或 WebUI 6099 扫码 |
| 二维码扫了没反应 | 手机上没点「确认登录」 | 扫码后必须再点一次确认 |
| 二维码"过期了" | NapCat 每约 60 秒换一张 | 在 WebUI 页面里扫，它会自动刷新 |
| 连不上，日志 401 | token 没走 `Authorization: Bearer` 头 | 检查 NapCat 的 Token 字段是否填了 |
| 连不上，404 | URL 少了 `/ws` 路径 | 用 `ws://127.0.0.1:6199/ws` |
| 收到消息但不回复 | 没配大模型，或 `admins_id` 不对 | 配服务提供商；检查 provider 配置 |
| 管理指令没反应 | `admins_id` 是占位值 `["astrbot"]` | 改成你的 QQ 号并重启 |
| launchd 报 `EX_CONFIG` | `~/Documents` 隐私保护 | 日志放 `/tmp` 或 `~/Library/Logs` |
| `stop.sh` 停不掉 | `KeepAlive` 自动拉起 | 用 `launchctl bootout` |
| 点 Dock 启动后机器人失联 | 缺少 `--no-sandbox` | 用专用脚本启动 QQ |
| import AstrBot 报错 | Python < 3.12 | 升级到 3.12+ |
| pip 装得极慢 | 默认源在国外 | 加 `-i https://pypi.tuna.tsinghua.edu.cn/simple` |

---

## 十二、安全与合规

### 必须知道的

1. **NapCat 是第三方协议端**，通过非官方手段操作 QQ 客户端。腾讯不保证兼容，
   存在**账号被风控、限制登录**的可能。**不要用主号。**
2. **端口不要暴露公网**。6185（WebUI）、6099（NapCat）、6199（OneBot）
   全部绑 `127.0.0.1`。如果确实要远程访问，用 SSH 隧道：

   ```bash
   ssh -L 6185:127.0.0.1:6185 用户@服务器
   ```

3. **密钥文件权限收紧**：

   ```bash
   chmod 600 .dashpw .ob_token
   chmod 600 data/cmd_config.json     # 里面有 API Key
   ```

4. **群聊里注意发言边界**。机器人代表的是你，别说"这不是我说的"。

### 建议的部署顺序

```
先用小号跑通 → 观察一周风控情况 → 再决定是否加大使用强度
```

---

## 十三、附录

### A. 命令速查

```bash
# 启动 / 停止 / 状态
./start.sh
./stop.sh
./status.sh

# 日志
tail -f logs/astrbot.out

# WebUI
open http://localhost:6185

# 端口检查
lsof -nP -iTCP -sTCP:LISTEN | grep -E '6185|6199|6099'

# 重置 WebUI 密码
./.venv/bin/astrbot password --username astrbot

# NapCat 切回原版 QQ（macOS）
open napcat/NapCatInstaller.app   # 选「切换程序入口 原版 QQ」
```

### B. 给 Harness 的运维提示词

**排障**：

```
机器人不回复了，帮我按这个顺序查：
1. AstrBot 进程是否存活、6185 是否监听
2. 6199 是否有 NapCat 的 ESTABLISHED 连接
3. QQ 是否以 --no-sandbox 启动（NapCat 模式）
4. 日志最近 50 行有没有 error
5. 大模型 provider 是否正常加载
只报告发现，不要擅自重启。
```

**迁移**：

```
把这套 AstrBot+NapCat 迁移到另一台 Linux 机器。
需要迁移：data/ 目录（配置、会话库、技能）、.ob_token、.dashpw。
需要重做：Python 环境、NapCat 安装、systemd 服务。
注意 QQ 登录态跨机器不可迁移，必须重新扫码。
先给我一份迁移方案，再执行。
```

### C. 文件结构说明

```
qqbot/
├── .venv/                  # Python 虚拟环境
├── data/
│   ├── cmd_config.json     # 主配置（含 API Key、平台、管理员）
│   ├── data_v4.db          # 会话数据库
│   ├── skills/             # 技能包（SKILL.md 格式）
│   └── knowledge_base/     # 知识库
├── .dashpw                 # WebUI 密码（chmod 600）
├── .ob_token               # OneBot token（chmod 600）
├── logs/astrbot.out        # 应用日志
├── start.sh / stop.sh / status.sh
└── start-qq.command        # 以 NapCat 模式启动 QQ
```

### D. 参考链接

- AstrBot 文档：https://docs.astrbot.app
- AstrBot GitHub：https://github.com/AstrBotDevs/AstrBot
- NapCat 文档：https://napneko.github.io
- NapCat GitHub：https://github.com/NapNeko/NapCatQQ
- OneBot v11 标准：https://11.onebot.dev
- DeepSeek API：https://platform.deepseek.com/api_docs

---

## 许可

[MIT](LICENSE)。可自由使用、修改、分发，保留版权声明即可。

## 贡献

发现错误或版本差异，欢迎提 Issue / PR。提交前请确认：

- 不包含任何真实 token、API Key、QQ 号
- 涉及的命令经过实际验证
- 跨平台差异在文中标注清楚

## 免责声明

本项目仅用于技术学习与交流。NapCat 通过非官方方式操作 QQ 客户端，
使用第三方协议端存在账号被限制的风险，**请勿用于主号或商业用途**。
因使用本项目导致的账号异常、数据丢失等后果由使用者自行承担。

---

*本教程基于一次真实部署整理。如果你的网络环境、系统版本与文中不同，
把差异点丢给 DeepSeek Harness，让它先做勘察再动手 —— 这是这份文档最重要的一条建议。*
