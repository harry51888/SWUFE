#!/bin/bash

# 📚 选课社区一键启动脚本 (SQLite版本)
# 适用于快速部署和开发环境

set -e  # 出错时立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 显示启动横幅
show_banner() {
    echo -e "${CYAN}"
    echo "=================================================="
    echo "🎓 西南财经大学选课评价社区"
    echo "🚀 一键启动脚本 (SQLite版本)"
    echo "=================================================="
    echo -e "${NC}"
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
    local max_attempts=15
    local attempt=1

    log_info "等待 $service_name 启动 ($host:$port)..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z $host $port >/dev/null 2>&1; then
            log_success "$service_name 已成功启动"
            return 0
        fi
        
        printf "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo ""
    log_error "$service_name 启动超时"
    return 1
}

# 检查基本环境
check_environment() {
    log_step "检查运行环境..."
    
    # 检查 Python3
    if ! command_exists python3; then
        log_error "未找到 Python3，请先安装 Python3"
        exit 1
    fi
    local python_version=$(python3 --version | cut -d' ' -f2)
    log_info "Python 版本: $python_version"
    
    # 检查 Node.js
    if ! command_exists node; then
        log_error "未找到 Node.js，请先安装 Node.js"
        exit 1
    fi
    local node_version=$(node --version)
    log_info "Node.js 版本: $node_version"
    
    # 检查 Yarn
    if ! command_exists yarn; then
        log_warning "未找到 Yarn，尝试安装..."
        npm install -g yarn
    fi
    local yarn_version=$(yarn --version)
    log_info "Yarn 版本: $yarn_version"
    
    log_success "环境检查完成"
}

# 停止已运行的服务
stop_existing_services() {
    log_step "停止已运行的服务..."
    
    # 停止前端服务 (端口 3000)
    if port_in_use 3000; then
        log_info "停止端口 3000 上的服务..."
        lsof -ti:3000 | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
    
    # 停止后端服务 (端口 8000)
    if port_in_use 8000; then
        log_info "停止端口 8000 上的服务..."
        lsof -ti:8000 | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
    
    # 清理PID文件
    rm -f backend.pid frontend.pid
    
    log_success "已停止冲突的服务"
}

# 设置代理环境
setup_proxy() {
    export https_proxy=http://127.0.0.1:7890
    export http_proxy=http://127.0.0.1:7890
    export all_proxy=socks5://127.0.0.1:7890
    log_info "已设置网络代理"
}

# 设置后端服务
setup_backend() {
    log_step "设置后端服务 (Django + SQLite)..."
    
    cd jcourse_api-master
    
    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建 Python 虚拟环境..."
        python3 -m venv venv
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 升级 pip
    pip install --upgrade pip --quiet
    
    # 安装依赖
    log_info "检查并安装 Python 依赖..."
    if [ -f "requirements_compatible.txt" ]; then
        pip install -r requirements_compatible.txt --quiet
    else
        log_error "未找到 requirements_compatible.txt 文件"
        exit 1
    fi
    
    # 创建 SQLite 配置文件
    if [ ! -f "jcourse/sqlite_settings.py" ]; then
        log_info "创建 SQLite 配置文件..."
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

# 安全设置
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
EOF
    fi
    
    # 执行数据库迁移
    log_info "执行数据库迁移..."
    python manage.py migrate --settings=jcourse.sqlite_settings --verbosity=0
    
    # 创建超级用户
    log_info "创建管理员账户..."
    echo "from django.contrib.auth.models import User; User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@example.com', 'admin')" | python manage.py shell --settings=jcourse.sqlite_settings
    
    # 导入课程数据（如果需要）
    if [ -f "../class-resource/课表.csv" ] && [ -f "jcourse_api/management/commands/import_schedule.py" ]; then
        log_info "导入课程数据..."
        python manage.py import_schedule ../class-resource/课表.csv --settings=jcourse.sqlite_settings || log_warning "课程数据导入失败，可以稍后手动导入"
    fi
    
    cd ..
    log_success "后端设置完成"
}

# 设置前端服务
setup_frontend() {
    log_step "设置前端服务 (Next.js)..."
    
    cd jcourse-master
    
    # 安装依赖
    log_info "检查并安装前端依赖..."
    yarn install --silent
    
    cd ..
    log_success "前端设置完成"
}

# 启动后端服务
start_backend() {
    log_step "启动后端服务..."
    
    cd jcourse_api-master
    source venv/bin/activate
    
    export DJANGO_SETTINGS_MODULE=jcourse.sqlite_settings
    export DEBUG=True
    
    # 后台启动 Django 服务
    nohup python manage.py runserver 127.0.0.1:8000 --settings=jcourse.sqlite_settings > ../backend.log 2>&1 &
    echo $! > ../backend.pid
    
    cd ..
    
    # 等待后端启动
    wait_for_service 127.0.0.1 8000 "后端API服务"
    
    log_success "后端服务已启动在 http://127.0.0.1:8000"
}

# 启动前端服务
start_frontend() {
    log_step "启动前端服务..."
    
    cd jcourse-master
    
    # 后台启动 Next.js 服务
    nohup yarn dev > ../frontend.log 2>&1 &
    echo $! > ../frontend.pid
    
    cd ..
    
    # 等待前端启动
    wait_for_service 127.0.0.1 3000 "前端界面服务"
    
    log_success "前端服务已启动在 http://localhost:3000"
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${GREEN}=================================================="
    echo "🎉 选课社区已成功启动！"
    echo "=================================================="
    echo -e "${NC}"
    echo -e "${CYAN}📱 前端界面:${NC} http://localhost:3000"
    echo -e "${CYAN}🔧 后端API:${NC}  http://127.0.0.1:8000"
    echo -e "${CYAN}👤 管理后台:${NC} http://127.0.0.1:8000/admin"
    echo ""
    echo -e "${YELLOW}📋 默认管理员账户:${NC}"
    echo "   用户名: admin"
    echo "   密码: admin"
    echo ""
    echo -e "${BLUE}📊 服务状态:${NC}"
    echo "   后端PID: $(cat backend.pid 2>/dev/null || echo '未知')"
    echo "   前端PID: $(cat frontend.pid 2>/dev/null || echo '未知')"
    echo ""
    echo -e "${PURPLE}🛠️ 常用命令:${NC}"
    echo "   停止服务: bash 停止选课社区.sh"
    echo "   查看日志: tail -f backend.log 或 tail -f frontend.log"
    echo ""
    echo -e "${GREEN}=================================================="
    echo -e "${NC}"
}

# 主函数
main() {
    show_banner
    
    # 设置代理
    setup_proxy
    
    # 检查环境
    check_environment
    
    # 停止已运行的服务
    stop_existing_services
    
    # 设置服务
    setup_backend
    setup_frontend
    
    # 启动服务
    start_backend
    start_frontend
    
    # 显示完成信息
    show_completion
}

# 执行主函数
main "$@" 