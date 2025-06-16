#!/bin/bash

# 选课社区一键启动脚本
# 适用于 macOS 系统

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

# 检查并安装依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查 Homebrew
    if ! command_exists brew; then
        log_error "未找到 Homebrew，请先安装 Homebrew"
        log_info "安装命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    # 检查 Python3
    if ! command_exists python3; then
        log_warning "未找到 Python3，正在安装..."
        brew install python3
    fi
    
    # 检查 Node.js 和 Yarn
    if ! command_exists node; then
        log_warning "未找到 Node.js，正在安装..."
        brew install node
    fi
    
    if ! command_exists yarn; then
        log_warning "未找到 Yarn，正在安装..."
        npm install -g yarn
    fi
    
    # 检查 PostgreSQL
    if ! command_exists psql; then
        log_warning "未找到 PostgreSQL，正在安装..."
        brew install postgresql@15
        brew services start postgresql@15
    fi
    
    # 检查 Redis
    if ! command_exists redis-server; then
        log_warning "未找到 Redis，正在安装..."
        brew install redis
    fi
    
    log_success "系统依赖检查完成"
}

# 启动数据库服务
start_database_services() {
    log_info "启动数据库服务..."
    
    # 启动 PostgreSQL
    if ! port_in_use 5432; then
        log_info "启动 PostgreSQL..."
        brew services start postgresql@15
        wait_for_service localhost 5432 "PostgreSQL"
    else
        log_info "PostgreSQL 已在运行"
    fi
    
    # 启动 Redis
    if ! port_in_use 6379; then
        log_info "启动 Redis..."
        brew services start redis
        wait_for_service localhost 6379 "Redis"
    else
        log_info "Redis 已在运行"
    fi
}

# 设置数据库
setup_database() {
    log_info "设置数据库..."
    
    # 创建数据库用户和数据库
    if ! psql -U $(whoami) postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='jcourse'" | grep -q 1; then
        log_info "创建数据库用户 jcourse..."
        psql -U $(whoami) postgres -c "CREATE USER jcourse WITH PASSWORD 'jcourse';"
        psql -U $(whoami) postgres -c "ALTER USER jcourse CREATEDB;"
    fi
    
    if ! psql -U $(whoami) postgres -tAc "SELECT 1 FROM pg_database WHERE datname='jcourse'" | grep -q 1; then
        log_info "创建数据库 jcourse..."
        psql -U $(whoami) postgres -c "CREATE DATABASE jcourse OWNER jcourse;"
    fi
    
    log_success "数据库设置完成"
}

# 设置后端
setup_backend() {
    log_info "设置后端..."
    
    cd jcourse_api-master
    
    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建 Python 虚拟环境..."
        python3 -m venv venv
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 安装依赖
    log_info "安装 Python 依赖..."
    pip install -r requirements.txt
    
    # 设置环境变量
    export POSTGRES_PASSWORD=jcourse
    export POSTGRES_HOST=localhost
    export DEBUG=True
    
    # 数据库迁移
    log_info "执行数据库迁移..."
    python manage.py migrate
    
    # 创建超级用户（如果不存在）
    if ! python manage.py shell -c "from django.contrib.auth.models import User; print(User.objects.filter(is_superuser=True).exists())" | grep -q True; then
        log_info "创建超级用户..."
        echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@example.com', 'admin')" | python manage.py shell
        log_success "超级用户创建完成 (用户名: admin, 密码: admin)"
    fi
    
    cd ..
    log_success "后端设置完成"
}

# 设置前端
setup_frontend() {
    log_info "设置前端..."
    
    cd jcourse-master
    
    # 安装依赖
    log_info "安装前端依赖..."
    yarn install
    
    cd ..
    log_success "前端设置完成"
}

# 导入课表数据
import_schedule() {
    log_info "导入课表数据..."
    
    cd jcourse_api-master
    source venv/bin/activate
    
    export POSTGRES_PASSWORD=jcourse
    export POSTGRES_HOST=localhost
    
    # 检查课表文件是否存在
    SCHEDULE_FILE="../class-resource/2024-2025-2课表(20250324)-2.csv"
    if [ -f "$SCHEDULE_FILE" ]; then
        python manage.py import_schedule "$SCHEDULE_FILE" --semester "2024-2025-2"
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
    export POSTGRES_PASSWORD=jcourse
    export POSTGRES_HOST=localhost
    export DEBUG=True
    nohup python manage.py runserver 0.0.0.0:8000 > ../backend.log 2>&1 &
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
    echo "🎉 选课社区启动成功！"
    echo "=================================================="
    echo ""
    echo "📱 前端访问地址: http://localhost:3000"
    echo "🔧 后端API地址:  http://localhost:8000"
    echo "🛠️  管理后台:     http://localhost:8000/admin"
    echo "   管理员账号:    admin"
    echo "   管理员密码:    admin"
    echo ""
    echo "📋 日志文件:"
    echo "   后端日志:      backend.log"
    echo "   前端日志:      frontend.log"
    echo ""
    echo "🔧 停止服务:"
    echo "   bash stop_jcourse.sh"
    echo ""
    echo "=================================================="
    echo ""
}

# 主函数
main() {
    echo "🚀 开始启动选课社区..."
    echo ""
    
    # 检查是否在正确的目录
    if [ ! -d "jcourse_api-master" ] || [ ! -d "jcourse-master" ]; then
        log_error "请在包含 jcourse_api-master 和 jcourse-master 目录的文件夹中运行此脚本"
        exit 1
    fi
    
    check_dependencies
    start_database_services
    setup_database
    setup_backend
    setup_frontend
    import_schedule
    start_services
    show_service_info
}

# 运行主函数
main "$@" 