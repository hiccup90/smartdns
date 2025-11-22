##############################################
# Stage 1: Downloader (fetch latest SmartDNS)
##############################################
FROM alpine:3.20 AS downloader

RUN apk add --no-cache curl jq

ARG REPO="pymumu/smartdns"

RUN API_URL="https://api.github.com/repos/${REPO}/releases/latest" && \
    ASSET_URL=$(curl -sL $API_URL | jq -r '.assets[] | select(.name | test("x86_64-linux-all\\.tar\\.gz$")) | .browser_download_url') && \
    curl -L -o /tmp/smartdns.tar.gz "$ASSET_URL"

RUN mkdir -p /tmp/smartdns && \
    tar -xzf /tmp/smartdns.tar.gz -C /tmp/smartdns --strip-components=1


##############################################
# Stage 2: Final Runtime (ultra slim)
##############################################
FROM alpine:3.20

# 安装必要组件（只保留 busybox-wget 代替 curl）
RUN apk add --no-cache tzdata busybox-suid && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    # 删除全部时区，保留 China
    rm -rf /usr/share/zoneinfo && \
    mkdir -p /usr/share/zoneinfo/Asia && \
    cp /etc/localtime /usr/share/zoneinfo/Asia/Shanghai && \
    mkdir -p /etc/smartdns /var/lib/smartdns /var/log/smartdns

# 复制 SmartDNS
COPY --from=downloader /tmp/smartdns/etc/ /etc/
COPY --from=downloader /tmp/smartdns/usr/ /usr/

EXPOSE 53/udp 6080/tcp

VOLUME ["/etc/smartdns", "/var/lib/smartdns"]

CMD ["/usr/sbin/smartdns", "-f", "-x"]
