FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y --no-install-recommends \
    sudo vim curl wget git net-tools ca-certificates build-essential ttyd \
    && apt clean && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# USER:PASS (đổi tùy bạn)
ENV USERNAME=root
ENV PASSWORD=root123

CMD ttyd -p $PORT -c ${USERNAME}:${PASSWORD} bash
