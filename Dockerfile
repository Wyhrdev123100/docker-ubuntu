FROM --platform=linux/amd64 ubuntu:22.04

# Thiết lập không tương tác
ENV DEBIAN_FRONTEND=noninteractive

# 1. Cài đặt các thành phần hệ thống và PufferPanel
RUN apt update && apt install -y --no-install-recommends \
    curl wget git sudo vim net-tools ca-certificates \
    python3 python3-pip nodejs npm gnupg2 \
    && curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | sudo bash \
    && apt install -y pufferpanel \
    && apt clean && rm -rf /var/lib/apt/lists/*

# 2. Cấu hình thư mục làm việc
WORKDIR /var/lib/pufferpanel

# 3. Tạo script khởi chạy hệ thống
# PufferPanel cần chạy trên cổng được Railway cấp ($PORT)
RUN echo '#!/bin/bash\n\
# Tạo user admin mặc định (Email: admin@admin.com | Pass: admin123)\n\
/usr/sbin/pufferpanel user create --name admin --email admin@admin.com --password admin123 --admin\n\
\n\
# Ghi đè cổng của PufferPanel bằng cổng Railway cấp\n\
sed -i "s/8080/$PORT/g" /etc/pufferpanel/config.json\n\
\n\
# Khởi chạy PufferPanel\n\
/usr/sbin/pufferpanel run' > /start.sh && chmod +x /start.sh

# Railway sử dụng cổng công khai
EXPOSE 8080

CMD ["/start.sh"]
