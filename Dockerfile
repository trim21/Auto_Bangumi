# syntax=docker/dockerfile:1

FROM python:3.11-slim as builder

RUN  --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
     --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update &&\
    apt-get install -y ccache build-essential libxml2-dev zlib1g-dev libxslt-dev xz-utils unzip jq bash


ARG S6_OVERLAY_VERSION=3.1.4.1
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN mkdir -p /s6/ && tar -C /s6/ -Jxpf /tmp/s6-overlay-x86_64.tar.xz


WORKDIR /app
COPY requirements.txt .

RUN   --mount=target=/root/.cache/pip,type=cache,sharing=locked \
      --mount=target=/root/.ccache,type=cache,sharing=locked \
    pip install cython && pip install --user -r requirements.txt


# Download WebUI without curl/wget
ADD "https://github.com/Rewrite0/Auto_Bangumi_WebUI/releases/latest/download/dist.zip" /tmp/dist.zip
RUN unzip -q -d /app/templates /tmp/dist.zip

FROM python:3.11-slim

ENV S6_SERVICES_GRACETIME=30000 \
    S6_KILL_GRACETIME=60000 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_SYNC_DISKS=1 \
    TERM="xterm" \
    HOME="/ab" \
    LANG="C.UTF-8" \
    TZ=Asia/Shanghai \
    PUID=1000 \
    PGID=1000 \
    UMASK=022

COPY --from=builder /root/.local /root/.local
COPY --from=builder /s6/ /
COPY --from=builder /app/templates /app/
COPY --from=builder /usr/bin/jq /bin/bash /bin/

# Add user
RUN mkdir /ab && \
    addgroup --group ab --gid 911 && \
    adduser ab ab -h /ab --shell /bin/bash -u 911

COPY --chmod=755 src/. .
COPY --chmod=755 ./docker /

ENTRYPOINT [ "/init" ]

EXPOSE 7892
VOLUME [ "/app/config" , "/app/data" ]
