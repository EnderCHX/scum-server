# SCUM Dedicated Server (Docker)

基于 Arch Linux 的 SCUM 专用服务器 Docker 镜像，通过 [Wine](https://www.winehq.org/) 运行 Windows 版 `SCUMServer.exe`。参考 [SCUM Wiki](https://scum.wiki.gg/wiki/Scum_Dedicated_server_setup)。

## 系统要求

| 资源 | 最低               | 推荐                   |
| ---- | ------------------ | ---------------------- |
| 内存 | 8 GB               | 16 GB+                 |
| 磁盘 | 15 GB              | 30 GB+（含存档与更新） |
| 网络 | 公网 IP 或端口转发 | —                      |

## 快速开始

### 构建镜像

```bash
docker build -t scum-server .
```

### 运行服务器

```bash
docker run -it --rm \
  --name scum-server \
  -p 7777:7777/udp \
  -p 7777:7777/tcp \
  -p 7778:7778/udp \
  -p 7779:7779/udp \
  -v scum-data:/scum_server/SCUM/Saved \
  scum-server
```

首次启动自动下载 SCUM 服务端（App ID: 3792580），约 **15-20 GB**，含自动重试机制。

### 常用参数

```bash
docker run -it --rm \
  --name scum-server \
  -e MAX_PLAYERS=32 \
  -e GAME_PORT=7777 \
  -e nobattleye=1 \
  -p 7777:7777/udp -p 7777:7777/tcp \
  -p 7778:7778/udp -p 7779:7779/udp \
  scum-server
```

## 端口说明

| 端口  | 协议      | 用途                                      |
| ----- | --------- | ----------------------------------------- |
| 7777  | UDP + TCP | 游戏端口（TCP 可选用于 RCON）             |
| 7778  | UDP       | Raw UDP 端口（游戏端口 +1）               |
| 7779  | UDP + TCP | Query 端口（游戏端口 +2，Steam 浏览器用） |
| 28015 | TCP       | RCON 端口（scum-rcon 插件）               |

> **注意：** Query 端口不可使用 27020-27050（Steam 预留）。多实例依次递增端口如 `7780/7781/7782`。

## 环境变量

| 变量                | 说明                                           | 默认值                 |
| ------------------- | ---------------------------------------------- | ---------------------- |
| `GAME_PORT`         | 游戏端口（Query = 此值 +2，Raw UDP = 此值 +1） | `7777`                 |
| `MAX_PLAYERS`       | 最大玩家数                                     | `64`                   |
| `nobattleye`        | 设为任意非空值禁用 BattlEye                    | 空（启用）             |
| `RCON_BIND_ADDRESS` | RCON 监听地址                                  | `127.0.0.1`            |
| `RCON_PORT`         | RCON 监听端口                                  | `28015`                |
| `RCON_PASSWORD`     | RCON 密码（必须修改，否则监听器拒绝启动）      | `CHANGE_ME_BEFORE_USE` |

## 配置文件

服务端配置文件位于 `Saved/Config/WindowsServer/` 目录。

```bash
mkdir -p ./scum-config

docker run -it --rm \
  -v ./scum-config:/scum_server/SCUM/Saved \
  -p 7777:7777/udp -p 7777:7777/tcp \
  -p 7778:7778/udp -p 7779:7779/udp \
  scum-server
```

首次运行后在 `./scum-config/` 中生成核心配置：

- `GameUserSettings.ini` — 服务器名称、密码、最大玩家数
- `ServerSettings.ini` — 服务器行为参数

## Docker Compose

```yaml
services:
  scum-server:
    build: .
    container_name: scum-server
    ports:
      - "7777:7777/udp"
      - "7777:7777/tcp"
      - "7778:7778/udp"
      - "7779:7779/udp"
    volumes:
      - scum-data:/scum_server/SCUM/Saved
    environment:
      MAX_PLAYERS: 32
      # nobattleye: 1
    stdin_open: true
    tty: true

volumes:
  scum-data:
```

```bash
docker compose up -d
```

## RCON 管理（scum-rcon 插件）

镜像内置 [scum-rcon](https://github.com/vasudh1/scum-rcon) 插件，基于 UE4SS + Source RCON 协议。支持标准 RCON 客户端（mcrcon、rcon-cli、BattleMetrics 等），可在远端执行大部分 SCUM 管理命令。

### 前置条件

- **必须禁用 BattlEye**：启动时添加 `-e nobattleye=1`
- **必须修改默认密码**：设置 `-e RCON_PASSWORD=你的强密码`

> ⚠️ 仅用于私有/白名单服务器，**不要**在 BattlEye 保护下的公开服务器使用。

### 运行示例

```bash
docker run -d \
  --name scum-server \
  -v scum-data:/scum_server \
  -p 7777:7777/udp -p 7777:7777/tcp \
  -p 7778:7778/udp -p 7779:7779/udp \
  -p 28015:28015/tcp \
  -e nobattleye=1 \
  -e RCON_BIND_ADDRESS=0.0.0.0 \
  -e RCON_PORT=28015 \
  -e RCON_PASSWORD=your-strong-password \
  scum-server
```

### 连接测试

使用 [mcrcon](https://github.com/Tiiffi/mcrcon) 测试：

```bash
mcrcon -H <服务器IP> -P 28015 -p your-strong-password "$broadcast Hello from RCON"
```

### RCON 命令要点

- 直接发送命令动词，**不需要**加 `#`（如 `SpawnItem ...` 而非 `#SpawnItem ...`）
- 含空格的参数用双引号包裹：`Teleport 1000 2000 300 "Player Name"`
- 目标玩家使用 17 位 SteamID64
- 大部分 SCUM 的 230+ 管理命令可直接使用

## 服务器管理

查看日志：

```bash
docker logs -f scum-server
```

停止：

```bash
docker stop scum-server
```

进入容器：

```bash
docker exec -it scum-server bash
```

## 更新服务端

删除容器后重新启动即可，SteamCMD 使用 `validate` 参数确保文件完整性：

```bash
docker rm -f scum-server
docker run -it --rm \
  --name scum-server \
  -v scum-data:/scum_server/SCUM/Saved \
  -p 7777:7777/udp -p 7777:7777/tcp \
  -p 7778:7778/udp -p 7779:7779/udp \
  scum-server
```

## 在服务器列表中查找

- Steam 客户端「查看 → 游戏服务器」按 IP:7777 搜索
- 添加 `你的IP:7777` 到 Steam 收藏，游戏内「收藏」标签加入
- 游戏内列表有显示上限，不保证始终出现

## 技术细节

| 项目       | 说明                                       |
| ---------- | ------------------------------------------ |
| 基础镜像   | `archlinux:latest`                         |
| Wine       | 运行 64 位 Windows 版 `SCUMServer.exe`     |
| SteamCMD   | Valve 官方预编译版，安装于 `/opt/steamcmd` |
| 包源       | 清华大学 Arch Linux 镜像                   |
| 服务端路径 | `/scum_server/`                            |
| App ID     | `3792580`                                  |

## 常见问题

### Missing configuration / 下载失败

SteamCMD 对 SCUM 服务端存在已知临时同步 bug。容器内置自动重试（最多 5 次），每次清理残留缓存后重试。

如持续失败，检查网络连通性或使用代理。

### 服务器配置

在 `GameUserSettings.ini` 中修改服务器名称、密码等参数，重启容器生效。

## 参考

- [SCUM Wiki - Dedicated Server Setup](https://scum.wiki.gg/wiki/Scum_Dedicated_server_setup)
- [SteamCMD 官方文档](https://developer.valvesoftware.com/wiki/SteamCMD)

## 许可

本仓库仅提供 Docker 构建脚本。SCUM 游戏本体版权归 Gamepires 所有。
