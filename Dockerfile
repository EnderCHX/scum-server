FROM archlinux:latest

# 合并所有 root 操作到单个 RUN 层：密钥初始化 -> 清华源 -> multilib -> 系统更新安装基础包 -> 缓存清理
RUN set -eux; \
    pacman-key --init; \
    pacman-key --populate archlinux; \
    echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist; \
    echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf; \
    pacman -Syu --noconfirm; \
    pacman -S --noconfirm base-devel git sudo wine lib32-glibc; \
    yes | pacman -Scc; \
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true

# 安装官方 steamcmd 到 /opt/steamcmd
RUN set -eux; \
    mkdir -p /opt/steamcmd; \
    curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -C /opt/steamcmd -xzvf -; \
    chmod +x /opt/steamcmd/steamcmd.sh /opt/steamcmd/linux32/steamcmd; \
    printf '#!/bin/bash\nexec /opt/steamcmd/steamcmd.sh "$@"\n' > /usr/local/bin/steamcmd; \
    chmod +x /usr/local/bin/steamcmd

# 下载 SCUM 服务端并清理 Steam 缓存，同时创建入口脚本
RUN mkdir -p /scum_server; \
    echo '#!/bin/bash' > /entrypoint.sh; \
    echo 'set -e' >> /entrypoint.sh; \
    echo '' >> /entrypoint.sh; \
    echo 'SERVER_EXE="/scum_server/SCUM/Binaries/Win64/SCUMServer.exe"' >> /entrypoint.sh; \
    echo 'if [ ! -f "$SERVER_EXE" ]; then' >> /entrypoint.sh; \
    echo '    echo "=== 首次启动，正在下载 SCUM 服务端 ==="' >> /entrypoint.sh; \
    echo '    # 清理可能损坏的 manifest 和 appcache，避免 Missing configuration 错误' >> /entrypoint.sh; \
    echo '    rm -f /root/Steam/appcache/appinfo.vdf /root/Steam/steamapps/appmanifest_3792580.acf' >> /entrypoint.sh; \
    echo '    # 重试最多 5 次，SteamCMD 对此 AppID 存在已知的临时同步 bug' >> /entrypoint.sh; \
    echo '    for i in 1 2 3 4 5; do' >> /entrypoint.sh; \
    echo '        echo "--- 第 $i 次尝试 ---"' >> /entrypoint.sh; \
    echo '        if steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir /scum_server +login anonymous +app_update 3792580 +quit; then' >> /entrypoint.sh; \
    echo '            echo "=== 下载完成 ==="' >> /entrypoint.sh; \
    echo '            break' >> /entrypoint.sh; \
    echo '        fi' >> /entrypoint.sh; \
    echo '        if [ "$i" -eq 5 ]; then' >> /entrypoint.sh; \
    echo '            echo "ERROR: 5 次下载均失败"' >> /entrypoint.sh; \
    echo '            exit 1' >> /entrypoint.sh; \
    echo '        fi' >> /entrypoint.sh; \
    echo '        echo "等待 5 秒后重试..."' >> /entrypoint.sh; \
    echo '        sleep 5' >> /entrypoint.sh; \
    echo '    done' >> /entrypoint.sh; \
    echo 'fi' >> /entrypoint.sh; \
    echo '' >> /entrypoint.sh; \
    echo 'GAME_PORT="${GAME_PORT:-7777}"' >> /entrypoint.sh; \
    echo 'MAX_PLAYERS="${MAX_PLAYERS:-64}"' >> /entrypoint.sh; \
    echo 'QUERY_PORT=$((GAME_PORT + 2))' >> /entrypoint.sh; \
    echo 'RAW_PORT=$((GAME_PORT + 1))' >> /entrypoint.sh; \
    echo 'EXTRA_ARGS=""' >> /entrypoint.sh; \
    echo 'if [ -n "$nobattleye" ]; then EXTRA_ARGS="$EXTRA_ARGS -nobattleye"; fi' >> /entrypoint.sh; \
    echo 'echo "=== SCUM Server ==="' >> /entrypoint.sh; \
    echo 'echo "Game Port:   $GAME_PORT (UDP+TCP)"' >> /entrypoint.sh; \
    echo 'echo "Raw UDP:     $RAW_PORT (UDP)"' >> /entrypoint.sh; \
    echo 'echo "Query Port:  $QUERY_PORT (UDP)"' >> /entrypoint.sh; \
    echo 'echo "Max Players: $MAX_PLAYERS"' >> /entrypoint.sh; \
    echo '[ -n "$nobattleye" ] && echo "BattlEye:    DISABLED"' >> /entrypoint.sh; \
    echo 'echo "===================="' >> /entrypoint.sh; \
    echo 'exec wine "$SERVER_EXE" -log -port=$GAME_PORT -MaxPlayers=$MAX_PLAYERS $EXTRA_ARGS' >> /entrypoint.sh; \
    chmod +x /entrypoint.sh

VOLUME ["/scum_server/SCUM/Saved"]
EXPOSE 7777/udp 7777/tcp 7778/udp 7779/udp

WORKDIR /scum_server
ENTRYPOINT ["/entrypoint.sh"]
