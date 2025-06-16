#!/bin/bash

# 选课社区简化启动脚本（使用 SQLite）
# 适用于快速体验，无需 PostgreSQL 和 Redis

set -e  # 出错时立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查端口是否被占用
port_in_use() {
    lsof -i :$1 >/dev/null 2>&1
}

# 等待服务启动
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=1

    log_info "等待 $service_name 启动 ($host:$port)..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z $host $port >/dev/null 2>&1; then
            log_success "$service_name 已启动"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "$service_name 启动超时"
    return 1
}

# 检查基本依赖
check_basic_dependencies() {
    log_info "检查基本依赖..."
    
    # 检查 Python3
    if ! command_exists python3; then
        log_error "未找到 Python3，请先安装 Python3"
        exit 1
    fi
    
    # 检查 Node.js 和 Yarn
    if ! command_exists node; then
        log_error "未找到 Node.js，请先安装 Node.js"
        exit 1
    fi
    
    if ! command_exists yarn; then
        log_warning "未找到 Yarn，尝试使用 npm 安装..."
        npm install -g yarn
    fi
    
    log_success "基本依赖检查完成"
}

# 设置后端（SQLite版本）
setup_backend_sqlite() {
    log_info "设置后端（使用 SQLite）..."
    
    cd jcourse_api-master
    
    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建 Python 虚拟环境..."
        python3 -m venv venv
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 设置代理（如果有的话）
    export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
    
    # 升级 pip
    log_info "升级 pip..."
    pip install --upgrade pip
    
    # 安装依赖
    log_info "安装 Python 依赖..."
    pip install -r requirements_compatible.txt
    
    # 创建 SQLite 设置文件
    cat > jcourse/sqlite_settings.py << 'EOF'
import os
from .settings import *

# 使用 SQLite 数据库
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# 禁用 Redis 缓存
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}

# 调试模式
DEBUG = True
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '*']

# CORS 设置
CORS_ORIGIN_WHITELIST = [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
]

CORS_ALLOW_ALL_ORIGINS = True

# 移除可能引起问题的应用
INSTALLED_APPS = [app for app in INSTALLED_APPS if app not in ['debug_toolbar']]

# 移除可能引起问题的中间件
MIDDLEWARE = [middleware for middleware in MIDDLEWARE if 'debug_toolbar' not in middleware]

# 禁用一些不必要的设置
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
EOF
    
    # 设置环境变量
    export DJANGO_SETTINGS_MODULE=jcourse.sqlite_settings
    export DEBUG=True
    
    # 数据库迁移
    log_info "执行数据库迁移..."
    python manage.py migrate --settings=jcourse.sqlite_settings
    
    # 创建超级用户（如果不存在）
    log_info "创建超级用户..."
    echo "from django.contrib.auth.models import User; User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@example.com', 'admin')" | python manage.py shell --settings=jcourse.sqlite_settings
    log_success "超级用户创建完成 (用户名: admin, 密码: admin)"
    
    cd ..
    log_success "后端设置完成"
}

# 设置前端
setup_frontend() {
    log_info "设置前端..."
    
    cd jcourse-master
    
    # 设置代理
    export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
    
    # 安装依赖
    log_info "安装前端依赖..."
    yarn install
    
    cd ..
    log_success "前端设置完成"
}

# 导入课表数据（SQLite版本）
import_schedule_sqlite() {
    log_info "导入课表数据..."
    
    cd jcourse_api-master
    source venv/bin/activate
    
    export DJANGO_SETTINGS_MODULE=jcourse.sqlite_settings
    
    # 检查课表文件是否存在
    SCHEDULE_FILE="../class-resource/2024-2025-2课表(20250324)-2.csv"
    if [ -f "$SCHEDULE_FILE" ]; then
        python manage.py import_schedule "$SCHEDULE_FILE" --semester "2024-2025-2" --settings=jcourse.sqlite_settings
        log_success "课表数据导入完成"
    else
        log_warning "课表文件不存在: $SCHEDULE_FILE"
    fi
    
    cd ..
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 检查端口占用
    if port_in_use 8000; then
        log_warning "端口 8000 已被占用，将尝试终止现有进程..."
        lsof -ti:8000 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    if port_in_use 3000; then
        log_warning "端口 3000 已被占用，将尝试终止现有进程..."
        lsof -ti:3000 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # 启动后端
    log_info "启动后端服务..."
    cd jcourse_api-master
    source venv/bin/activate
    export DJANGO_SETTINGS_MODULE=jcourse.sqlite_settings
    export DEBUG=True
    nohup python manage.py runserver 0.0.0.0:8000 --settings=jcourse.sqlite_settings > ../backend.log 2>&1 &
    BACKEND_PID=$!
    cd ..
    
    # 等待后端启动
    wait_for_service localhost 8000 "后端服务"
    
    # 启动前端
    log_info "启动前端服务..."
    cd jcourse-master
    export REMOTE_URL=http://localhost:8000
    nohup yarn dev > ../frontend.log 2>&1 &
    FRONTEND_PID=$!
    cd ..
    
    # 等待前端启动
    wait_for_service localhost 3000 "前端服务"
    
    # 保存进程ID
    echo $BACKEND_PID > backend.pid
    echo $FRONTEND_PID > frontend.pid
    
    log_success "所有服务启动完成!"
}

# 显示服务信息
show_service_info() {
    echo ""
    echo "=================================================="
    echo "🎉 选课社区启动成功！(SQLite版本)"
    echo "=================================================="
    echo ""
    echo "📱 前端访问地址: http://localhost:3000"
    echo "🔧 后端API地址:  http://localhost:8000"
    echo "🛠️  管理后台:     http://localhost:8000/admin"
    echo "   管理员账号:    admin"
    echo "   管理员密码:    admin"
    echo ""
    echo "💾 数据库:        SQLite (jcourse_api-master/db.sqlite3)"
    echo ""
    echo "📋 日志文件:"
    echo "   后端日志:      backend.log"
    echo "   前端日志:      frontend.log"
    echo ""
    echo "🔧 停止服务:"
    echo "   bash stop_jcourse.sh"
    echo ""
    echo "ℹ️  注意: 这是使用 SQLite 的简化版本，适合快速体验"
    echo "   生产环境建议使用 PostgreSQL 版本"
    echo ""
    echo "=================================================="
    echo ""
}

# 主函数
main() {
    echo "🚀 开始启动选课社区（SQLite 版本）..."
    echo ""
    
    # 检查是否在正确的目录
    if [ ! -d "jcourse_api-master" ] || [ ! -d "jcourse-master" ]; then
        log_error "请在包含 jcourse_api-master 和 jcourse-master 目录的文件夹中运行此脚本"
        exit 1
    fi
    
    check_basic_dependencies
    setup_backend_sqlite
    setup_frontend
    import_schedule_sqlite
    start_services
    show_service_info
}

# 运行主函数
main "$@" 