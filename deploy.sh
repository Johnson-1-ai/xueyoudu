#!/usr/bin/env bash
# 学有度 · 一键部署脚本（香港服务器上以 root 运行）
# 用法: bash deploy.sh 你的域名.com
set -euo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "用法: bash deploy.sh 你的域名.com"
  exit 1
fi

SUPABASE_ORIGIN="https://izajwocvopaiaspmzdkj.supabase.co"
REPO_RAW="https://raw.githubusercontent.com/Johnson-1-ai/xueyoudu/main"

echo "==> 1/5 安装 Caddy（Web 服务器 + 自动 HTTPS）..."
if ! command -v caddy >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -y
  apt-get install -y caddy
fi

echo "==> 2/5 下载网页文件..."
mkdir -p /var/www/xueyoudu
curl -fsSL "$REPO_RAW/index.html" -o /var/www/xueyoudu/index.html

echo "==> 3/5 把后端地址改成你的域名（同源反代，避免 CORS）..."
sed -i "s#${SUPABASE_ORIGIN}#https://${DOMAIN}#g" /var/www/xueyoudu/index.html

echo "==> 4/5 写 Caddy 配置..."
mkdir -p /etc/caddy
cat > /etc/caddy/Caddyfile <<CFG
${DOMAIN} {
    root * /var/www/xueyoudu
    encode gzip
    file_server

    handle /auth/v1/* {
        reverse_proxy ${SUPABASE_ORIGIN}
    }
    handle /rest/v1/* {
        reverse_proxy ${SUPABASE_ORIGIN}
    }
    handle /storage/v1/* {
        reverse_proxy ${SUPABASE_ORIGIN}
    }
}
CFG

echo "==> 5/5 启动 Caddy..."
systemctl enable caddy >/dev/null 2>&1 || true
systemctl restart caddy

echo ""
echo "✅ 部署完成！"
echo "   - 请确认：① 域名 A 记录已指向本机公网 IP；② 控制台防火墙已放行 80 和 443 端口"
echo "   - 等 1~2 分钟证书自动签发后，访问: https://${DOMAIN}"
echo "   - 若打不开，先跑: systemctl status caddy 看报错"
