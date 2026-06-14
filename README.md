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

| 端口 | 协议      | 用途                                      |
| ---- | --------- | ----------------------------------------- |
| 7777 | UDP + TCP | 游戏端口（TCP 可选用于 RCON）             |
| 7778 | UDP       | Raw UDP 端口（游戏端口 +1）               |
| 7779 | UDP       | Query 端口（游戏端口 +2，Steam 浏览器用） |

> **注意：** Query 端口不可使用 27020-27050（Steam 预留）。多实例依次递增端口如 `7780/7781/7782`。

## 环境变量

| 变量          | 说明                                           | 默认值     |
| ------------- | ---------------------------------------------- | ---------- |
| `GAME_PORT`   | 游戏端口（Query = 此值 +2，Raw UDP = 此值 +1） | `7777`     |
| `MAX_PLAYERS` | 最大玩家数                                     | `64`       |
| `nobattleye`  | 设为任意非空值禁用 BattlEye                    | 空（启用） |

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
