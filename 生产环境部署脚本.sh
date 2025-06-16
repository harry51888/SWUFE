#!/bin/bash

# 🏭 选课社区生产环境部署脚本
# 适用于 Ubuntu 云服务器

set -e  # 出错时立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
DOMAIN="swufe.kaixuebang.com"
PROJECT_NAME="jcourse"
PROJECT_DIR="/opt/jcourse"
BACKEND_DIR="$PROJECT_DIR/jcourse_api-master"
FRONTEND_DIR="$PROJECT_DIR/jcourse-master"
NGINX_CONF="/etc/nginx/sites-available/$PROJECT_NAME"
SYSTEMD_BACKEND="/etc/systemd/system/jcourse-backend.service"
SYSTEMD_FRONTEND="/etc/systemd/system/jcourse-frontend.service"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 显示部署横幅
show_banner() {
    echo -e "${CYAN}"
    echo "=================================================="
    echo "🏭 西南财经大学选课评价社区"
    echo "🚀 生产环境部署脚本"
    echo "🌐 域名: $DOMAIN"
    echo "=================================================="
    echo -e "${NC}"
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 更新系统包
update_system() {
    log_step "更新系统包..."
    apt update -y
    apt upgrade -y
    log_success "系统包更新完成"
}

# 安装基本依赖
install_dependencies() {
    log_step "安装基本依赖..."
    
    # 安装基础包
    apt install -y \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        supervisor \
        certbot \
        python3-certbot-nginx
    
    log_success "基本依赖安装完成"
}

# 安装Python 3.11
install_python() {
    log_step "安装Python 3.11..."
    
    # 添加deadsnakes PPA
    add-apt-repository ppa:deadsnakes/ppa -y
    apt update -y
    
    # 安装Python 3.11及相关包
    apt install -y \
        python3.11 \
        python3.11-venv \
        python3.11-dev \
        python3-pip
    
    # 创建python3链接
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
    
    log_success "Python 3.11安装完成"
}

# 安装Node.js
install_nodejs() {
    log_step "安装Node.js 18 LTS..."
    
    # 安装NodeSource仓库
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    
    # 安装yarn
    npm install -g yarn pm2
    
    log_success "Node.js和Yarn安装完成"
}

# 安装PostgreSQL
install_postgresql() {
    log_step "安装PostgreSQL..."
    
    apt install -y postgresql postgresql-contrib postgresql-client
    
    # 启动并启用PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    log_success "PostgreSQL安装完成"
}

# 安装Redis
install_redis() {
    log_step "安装Redis..."
    
    apt install -y redis-server
    
    # 配置Redis
    sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
    
    # 启动并启用Redis
    systemctl restart redis-server
    systemctl enable redis-server
    
    log_success "Redis安装完成"
}

# 安装Nginx
install_nginx() {
    log_step "安装Nginx..."
    
    apt install -y nginx
    
    # 启动并启用Nginx
    systemctl start nginx
    systemctl enable nginx
    
    log_success "Nginx安装完成"
}

# 创建项目用户
create_user() {
    log_step "创建项目用户..."
    
    # 创建用户
    if ! id "jcourse" &>/dev/null; then
        useradd -m -s /bin/bash jcourse
        log_success "用户jcourse创建完成"
    else
        log_info "用户jcourse已存在"
    fi
    
    # 创建项目目录
    mkdir -p $PROJECT_DIR
    chown jcourse:jcourse $PROJECT_DIR
}

# 配置PostgreSQL
setup_postgresql() {
    log_step "配置PostgreSQL..."
    
    # 创建数据库和用户
    sudo -u postgres psql << EOF
CREATE DATABASE jcourse_db;
CREATE USER jcourse_user WITH PASSWORD 'jcourse_password_2024';
ALTER ROLE jcourse_user SET client_encoding TO 'utf8';
ALTER ROLE jcourse_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE jcourse_user SET timezone TO 'Asia/Shanghai';
GRANT ALL PRIVILEGES ON DATABASE jcourse_db TO jcourse_user;
\q
EOF
    
    log_success "PostgreSQL数据库配置完成"
}

# 上传项目文件
upload_project() {
    log_step "准备项目文件..."
    
    # 这里需要从本地上传文件到服务器
    # 或者从Git仓库克隆
    log_info "请确保项目文件已上传到 $PROJECT_DIR"
    log_info "包含目录: jcourse_api-master, jcourse-master, class-resource"
}

# 配置后端
setup_backend() {
    log_step "配置后端服务..."
    
    cd $BACKEND_DIR
    
    # 创建虚拟环境
    sudo -u jcourse python3.11 -m venv venv
    
    # 激活虚拟环境并安装依赖
    sudo -u jcourse bash -c "
        source venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements_compatible.txt
        pip install gunicorn psycopg2-binary
    "
    
    # 创建生产环境配置文件
    cat > jcourse/production_settings.py << 'EOF'
import os
from .settings import *

# 生产环境配置
DEBUG = False
ALLOWED_HOSTS = ['swufe.kaixuebang.com', '101.36.111.202', 'localhost', '127.0.0.1']

# 数据库配置
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'jcourse_db',
        'USER': 'jcourse_user',
        'PASSWORD': 'jcourse_password_2024',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

# Redis缓存配置
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': 'redis://127.0.0.1:6379/1',
    }
}

# 静态文件配置
STATIC_URL = '/static/'
STATIC_ROOT = '/opt/jcourse/static'
MEDIA_URL = '/media/'
MEDIA_ROOT = '/opt/jcourse/media'

# CORS配置
CORS_ORIGIN_WHITELIST = [
    'https://swufe.kaixuebang.com',
    'http://swufe.kaixuebang.com',
]

CORS_ALLOW_ALL_ORIGINS = False

# 安全设置
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

# 日志配置
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/opt/jcourse/logs/django.log',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['file'],
        'level': 'INFO',
    },
}
EOF
    
    # 创建日志目录
    mkdir -p /opt/jcourse/logs
    mkdir -p /opt/jcourse/static
    mkdir -p /opt/jcourse/media
    chown -R jcourse:jcourse /opt/jcourse/logs
    chown -R jcourse:jcourse /opt/jcourse/static
    chown -R jcourse:jcourse /opt/jcourse/media
    
    # 执行数据库迁移
    sudo -u jcourse bash -c "
        cd $BACKEND_DIR
        source venv/bin/activate
        export DJANGO_SETTINGS_MODULE=jcourse.production_settings
        python manage.py migrate
        python manage.py collectstatic --noinput
        echo \"from django.contrib.auth.models import User; User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@swufe.edu.cn', 'admin123456')\" | python manage.py shell
    "
    
    # 导入课程数据
    if [ -f "$PROJECT_DIR/class-resource/课表.csv" ]; then
        sudo -u jcourse bash -c "
            cd $BACKEND_DIR
            source venv/bin/activate
            export DJANGO_SETTINGS_MODULE=jcourse.production_settings
            python manage.py import_schedule $PROJECT_DIR/class-resource/课表.csv
        "
    fi
    
    log_success "后端配置完成"
}

# 配置前端
setup_frontend() {
    log_step "配置前端服务..."
    
    cd $FRONTEND_DIR
    
    # 创建环境配置文件
    cat > .env.local << EOF
NEXT_PUBLIC_API_URL=https://swufe.kaixuebang.com/api
NEXT_PUBLIC_SITE_URL=https://swufe.kaixuebang.com
NODE_ENV=production
EOF
    
    # 安装依赖并构建
    sudo -u jcourse bash -c "
        cd $FRONTEND_DIR
        yarn install
        yarn build
    "
    
    log_success "前端配置完成"
}

# 创建systemd服务
create_systemd_services() {
    log_step "创建systemd服务..."
    
    # 后端服务
    cat > $SYSTEMD_BACKEND << EOF
[Unit]
Description=JCourse Backend (Gunicorn)
After=network.target postgresql.service redis.service
Wants=postgresql.service redis.service

[Service]
Type=notify
User=jcourse
Group=jcourse
WorkingDirectory=$BACKEND_DIR
Environment=DJANGO_SETTINGS_MODULE=jcourse.production_settings
ExecStart=$BACKEND_DIR/venv/bin/gunicorn --bind 127.0.0.1:8000 --workers 3 --timeout 120 --access-logfile /opt/jcourse/logs/gunicorn_access.log --error-logfile /opt/jcourse/logs/gunicorn_error.log jcourse.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 前端服务
    cat > $SYSTEMD_FRONTEND << EOF
[Unit]
Description=JCourse Frontend (Next.js)
After=network.target

[Service]
Type=exec
User=jcourse
Group=jcourse
WorkingDirectory=$FRONTEND_DIR
Environment=NODE_ENV=production
Environment=PORT=3000
ExecStart=/usr/bin/yarn start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd并启用服务
    systemctl daemon-reload
    systemctl enable jcourse-backend
    systemctl enable jcourse-frontend
    
    log_success "systemd服务创建完成"
}

# 配置Nginx
setup_nginx() {
    log_step "配置Nginx..."
    
    cat > $NGINX_CONF << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # 重定向到HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL配置 (Let's Encrypt证书)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    
    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 日志
    access_log /var/log/nginx/$DOMAIN.access.log;
    error_log /var/log/nginx/$DOMAIN.error.log;
    
    # 静态文件
    location /static/ {
        alias /opt/jcourse/static/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    location /media/ {
        alias /opt/jcourse/media/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    # API代理
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 管理后台
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # 前端应用
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    
    # 启用站点
    ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
    
    # 删除默认站点
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试配置
    nginx -t
    
    log_success "Nginx配置完成"
}

# 获取SSL证书
setup_ssl() {
    log_step "获取SSL证书..."
    
    # 临时停止Nginx
    systemctl stop nginx
    
    # 获取证书
    certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@swufe.edu.cn
    
    # 设置自动续期
    echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
    
    # 重启Nginx
    systemctl start nginx
    
    log_success "SSL证书配置完成"
}

# 启动所有服务
start_services() {
    log_step "启动所有服务..."
    
    # 启动数据库服务
    systemctl restart postgresql
    systemctl restart redis-server
    
    # 启动应用服务
    systemctl start jcourse-backend
    systemctl start jcourse-frontend
    
    # 重启Nginx
    systemctl restart nginx
    
    log_success "所有服务启动完成"
}

# 创建防火墙规则
setup_firewall() {
    log_step "配置防火墙..."
    
    # 安装ufw
    apt install -y ufw
    
    # 配置防火墙规则
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80
    ufw allow 443
    
    # 启用防火墙
    ufw --force enable
    
    log_success "防火墙配置完成"
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${GREEN}=================================================="
    echo "🎉 生产环境部署完成！"
    echo "=================================================="
    echo -e "${NC}"
    echo -e "${CYAN}🌐 网站地址:${NC} https://$DOMAIN"
    echo -e "${CYAN}👤 管理后台:${NC} https://$DOMAIN/admin"
    echo ""
    echo -e "${YELLOW}📋 默认管理员账户:${NC}"
    echo "   用户名: admin"
    echo "   密码: admin123456"
    echo ""
    echo -e "${BLUE}📊 服务状态检查:${NC}"
    echo "   systemctl status jcourse-backend"
    echo "   systemctl status jcourse-frontend"
    echo "   systemctl status nginx"
    echo "   systemctl status postgresql"
    echo "   systemctl status redis-server"
    echo ""
    echo -e "${PURPLE}📁 重要目录:${NC}"
    echo "   项目目录: $PROJECT_DIR"
    echo "   日志目录: /opt/jcourse/logs"
    echo "   静态文件: /opt/jcourse/static"
    echo ""
    echo -e "${GREEN}=================================================="
    echo -e "${NC}"
}

# 主函数
main() {
    show_banner
    
    # 检查权限
    check_root
    
    # 系统准备
    update_system
    install_dependencies
    
    # 安装运行环境
    install_python
    install_nodejs
    install_postgresql
    install_redis
    install_nginx
    
    # 项目配置
    create_user
    setup_postgresql
    upload_project
    
    # 等待用户上传文件
    echo ""
    read -p "请确认项目文件已上传到 $PROJECT_DIR，按回车继续..."
    
    # 配置应用
    setup_backend
    setup_frontend
    
    # 服务配置
    create_systemd_services
    setup_nginx
    setup_ssl
    setup_firewall
    
    # 启动服务
    start_services
    
    # 显示完成信息
    show_completion
}

# 执行主函数
main "$@" 