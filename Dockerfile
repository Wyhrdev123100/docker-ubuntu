FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y --no-install-recommends \
    curl wget git sudo vim net-tools ca-certificates \
    python3 python3-pip nodejs npm gnupg2 \
    && curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | sudo bash \
    && apt install -y pufferpanel \
    && apt clean && rm -rf /var/lib/apt/lists/*

WORKDIR /var/lib/pufferpanel

# Script khởi chạy đã sửa lỗi flag và thiếu file json
RUN echo '#!/bin/bash\n\
# 1. Khởi tạo cấu hình nếu chưa có\n\
/usr/sbin/pufferpanel init\n\
\n\
# 2. Tạo user bằng lệnh add (không dùng flag lỗi)\n\
# Lệnh này sẽ tạo user admin/admin123 nếu chưa tồn tại\n\
/usr/sbin/pufferpanel user add --name admin --password admin123 --email admin@admin.com --admin\n\
\n\
# 3. Ép PufferPanel nghe ở cổng Railway cấp ($PORT)\n\
# Và cho phép truy cập từ bên ngoài (0.0.0.0)\n\
sed -i "s/\"host\": \"127.0.0.1:8080\"/\"host\": \"0.0.0.0:$PORT\"/g" /etc/pufferpanel/config.json\n\
sed -i "s/8080/$PORT/g" /etc/pufferpanel/config.json\n\
\n\
# 4. Chạy Panel\n\
/usr/sbin/pufferpanel run' > /start.sh && chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
