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

RUN mkdir -p /tmp/smartdns \
    && tar -xzf /tmp/smartdns.tar.gz -C /tmp/smartdns --strip-components=1


##############################################
# Stage 2: Runtime (Slim Alpine)
##############################################
FROM alpine:3.20

# 构建时的 cron 配置 (默认：每天凌晨 3 点执行 update.sh)
ARG UPDATE="0 3 * * *"

# 安装最小依赖
RUN apk add --no-cache tzdata busybox-suid wget && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    # 删除所有时区，只保留上海
    rm -rf /usr/share/zoneinfo && \
    mkdir -p /usr/share/zoneinfo/Asia && \
    cp /etc/localtime /usr/share/zoneinfo/Asia/Shanghai && \
    mkdir -p /etc/smartdns /var/lib/smartdns /var/log/smartdns /etc/crontabs

# 拷贝 SmartDNS release 内容
COPY --from=downloader /tmp/smartdns/etc/ /etc/
COPY --from=downloader /tmp/smartdns/usr/ /usr/

# ⭐ 编译阶段“写死” cron（最优雅）
RUN echo "${UPDATE} /etc/smartdns/update.sh" > /etc/crontabs/root

# 暴露端口
EXPOSE 53/udp 6080/tcp

VOLUME ["/etc/smartdns", "/var/lib/smartdns"]

# 启动 crond + smartdns（无逻辑，无判断，非常干净）
CMD sh -c "crond && exec /usr/sbin/smartdns -f -x"
