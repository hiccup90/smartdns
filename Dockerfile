##############################################
# Stage 1: Downloader (fetch latest SmartDNS)
##############################################
FROM alpine:3.20 AS downloader

RUN apk add --no-cache curl jq bash

# SmartDNS Github Repo
ARG REPO="pymumu/smartdns"

# Fetch latest release asset (x86_64-linux-all)
RUN API_URL="https://api.github.com/repos/${REPO}/releases/latest" && \
    echo "Fetching SmartDNS latest release..." && \
    ASSET_URL=$(curl -sL $API_URL | \
        jq -r '.assets[] | select(.name | test("x86_64-linux-all\\.tar\\.gz$")) | .browser_download_url') && \
    echo "Found asset: $ASSET_URL" && \
    curl -L -o /tmp/smartdns.tar.gz "$ASSET_URL"

# Extract to /tmp/smartdns
RUN mkdir -p /tmp/smartdns && \
    tar -xzf /tmp/smartdns.tar.gz -C /tmp/smartdns --strip-components=1


##############################################
# Stage 2: Final SmartDNS Runtime Image
##############################################
FROM alpine:3.20

# =========== 体积极限优化 ===========
# 删除不必要文件（Alpine 已很小）
# 仅安装 tzdata/curl（给 update.sh 用）
RUN apk add --no-cache tzdata curl bash busybox-suid && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    mkdir -p /etc/smartdns /var/lib/smartdns /var/log/smartdns

# =========== 拷贝 SmartDNS 运行文件 ===========
COPY --from=downloader /tmp/smartdns/etc/ /etc/
COPY --from=downloader /tmp/smartdns/usr/ /usr/

# 暴露端口
EXPOSE 53/udp 6080/tcp

# 可挂载目录（配置 + 数据）
VOLUME ["/etc/smartdns", "/var/lib/smartdns"]

# SmartDNS 以前台模式启动
CMD ["/usr/sbin/smartdns", "-f", "-x"]
