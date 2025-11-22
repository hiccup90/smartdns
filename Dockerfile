##############################################
# Stage 1: Downloader (fetch latest SmartDNS)
##############################################
FROM alpine:3.20 AS downloader

RUN apk add --no-cache curl jq

ARG REPO="pymumu/smartdns"

RUN API_URL="https://api.github.com/repos/${REPO}/releases/latest" && \
    ASSET_URL=$(curl -sL $API_URL | jq -r '.assets[] | select(.name | test("x86_64-linux-all\\.tar\\.gz$")) | .browser_download_url') && \
    echo "Downloading: $ASSET_URL" && \
    curl -L -o /tmp/smartdns.tar.gz "$ASSET_URL"

RUN mkdir -p /tmp/smartdns && \
    tar -xzf /tmp/smartdns.tar.gz -C /tmp/smartdns --strip-components=1


##############################################
# Stage 2: Final Runtime (Slim Alpine)
##############################################
FROM alpine:3.20

# 安装最小依赖
RUN apk add --no-cache tzdata busybox-suid && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    rm -rf /usr/share/zoneinfo && \
    mkdir -p /usr/share/zoneinfo/Asia && \
    cp /etc/localtime /usr/share/zoneinfo/Asia/Shanghai && \
    mkdir -p /etc/smartdns /var/lib/smartdns /var/log/smartdns

# 拷贝 SmartDNS 文件
COPY --from=downloader /tmp/smartdns/etc/ /etc/
COPY --from=downloader /tmp/smartdns/usr/ /usr/

# 暴露端口
EXPOSE 53/udp 6080/tcp

# 可挂载目录
VOLUME ["/etc/smartdns", "/var/lib/smartdns"]

# 🟩 容器启动自动运行 crond + SmartDNS（关键改动）
CMD sh -c "crond && exec /usr/sbin/smartdns -f -x"
