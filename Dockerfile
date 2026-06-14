FROM archlinux:latest

# 合并所有 root 操作到单个 RUN 层：密钥初始化 -> 清华源 -> multilib -> 系统更新安装基础包 -> 缓存清理
RUN set -eux; \
    pacman-key --init; \
    pacman-key --populate archlinux; \
    echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist; \
    echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf; \
    pacman -Syu --noconfirm; \
    pacman -S --noconfirm base-devel git sudo wine lib32-glibc xorg-server-xvfb lib32-libpulse; \
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
    echo '' >> /entrypoint.sh; \
    echo '# 复制 scum-rcon 插件到 Win64 目录' >> /entrypoint.sh; \
    echo 'RCON_SRC="/opt/scum-rcon"' >> /entrypoint.sh; \
    echo 'WIN64_DIR="/scum_server/SCUM/Binaries/Win64"' >> /entrypoint.sh; \
    echo 'if [ -d "$RCON_SRC/ue4ss" ]; then' >> /entrypoint.sh; \
    echo '    echo "安装 scum-rcon 插件..."' >> /entrypoint.sh; \
    echo '    cp -r "$RCON_SRC/ue4ss" "$WIN64_DIR/"' >> /entrypoint.sh; \
    echo '    cp "$RCON_SRC/dwmapi.dll" "$WIN64_DIR/"' >> /entrypoint.sh; \
    echo '    RCON_INI="$WIN64_DIR/ue4ss/Mods/scum_rcon/config.ini"' >> /entrypoint.sh; \
    echo '    # 注入 RCON 配置 (环境变量覆盖 config.ini)' >> /entrypoint.sh; \
    echo '    RCON_PASS="${RCON_PASSWORD:-CHANGE_ME_BEFORE_USE}"' >> /entrypoint.sh; \
    echo '    RCON_BIND="${RCON_BIND_ADDRESS:-0.0.0.0}"' >> /entrypoint.sh; \
    echo '    RCON_PORT_NUM="${RCON_PORT:-28015}"' >> /entrypoint.sh; \
    echo '    # 使用 | 分隔符避免密码中特殊字符 (/ \&) 破坏 sed' >> /entrypoint.sh; \
    echo '    sed -i "s|^password = .*|password = $RCON_PASS|" "$RCON_INI"' >> /entrypoint.sh; \
    echo '    sed -i "s|^bind_address = .*|bind_address = $RCON_BIND|" "$RCON_INI"' >> /entrypoint.sh; \
    echo '    sed -i "s|^port = .*|port = $RCON_PORT_NUM|" "$RCON_INI"' >> /entrypoint.sh; \
    echo '    if [ "$RCON_PASS" = "CHANGE_ME_BEFORE_USE" ]; then' >> /entrypoint.sh; \
    echo '        echo "WARNING: RCON 密码仍为默认值，监听器将拒绝启动！"' >> /entrypoint.sh; \
    echo '        echo "        请设置环境变量 RCON_PASSWORD"' >> /entrypoint.sh; \
    echo '    fi' >> /entrypoint.sh; \
    echo '    echo "RCON 监听: $RCON_BIND:$RCON_PORT_NUM"' >> /entrypoint.sh; \
    echo '    echo "scum-rcon 插件安装完成"' >> /entrypoint.sh; \
    echo 'else' >> /entrypoint.sh; \
    echo '    echo "WARNING: scum-rcon 插件未找到，跳过"' >> /entrypoint.sh; \
    echo 'fi' >> /entrypoint.sh; \
    echo '' >> /entrypoint.sh; \
    echo '# Wine DLL 覆盖：dwmapi 代理注入 + 音频静默避免线程崩溃' >> /entrypoint.sh; \
    echo 'export WINEDLLOVERRIDES="dwmapi=n,b;mmdevapi=b;dsound=b;xaudio2_7=b"' >> /entrypoint.sh; \
    echo '# 启动虚拟 X 服务器 (SCUM 服务端需要一个显示设备)' >> /entrypoint.sh; \
    echo 'Xvfb :99 -screen 0 1024x768x24 &' >> /entrypoint.sh; \
    echo 'XVFB_PID=$!' >> /entrypoint.sh; \
    echo 'export DISPLAY=:99' >> /entrypoint.sh; \
    echo 'sleep 1  # 等待 Xvfb 就绪' >> /entrypoint.sh; \
    echo '' >> /entrypoint.sh; \
    echo 'wine "$SERVER_EXE" -log -port=$GAME_PORT -MaxPlayers=$MAX_PLAYERS $EXTRA_ARGS &' >> /entrypoint.sh; \
    echo 'WINE_PID=$!' >> /entrypoint.sh; \
    echo '' >> /entrypoint.sh; \
    echo '# 等待任一进程退出，然后清理' >> /entrypoint.sh; \
    echo 'wait -n $WINE_PID $XVFB_PID' >> /entrypoint.sh; \
    echo 'EXIT_CODE=$?' >> /entrypoint.sh; \
    echo 'kill $WINE_PID $XVFB_PID 2>/dev/null' >> /entrypoint.sh; \
    echo 'wait 2>/dev/null' >> /entrypoint.sh; \
    echo 'exit $EXIT_CODE' >> /entrypoint.sh; \
    chmod +x /entrypoint.sh

COPY scum-rcon/ /opt/scum-rcon/

VOLUME ["/scum_server"]
EXPOSE 7777/udp 7777/tcp 7778/udp 7778/tcp 7779/udp 7779/tcp



WORKDIR /scum_server
ENTRYPOINT ["/entrypoint.sh"]
