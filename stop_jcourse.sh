#!/bin/bash

# 选课社区停止脚本
# 适用于 macOS 系统

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

# 停止进程
stop_process() {
    local pid_file=$1
    local service_name=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p $pid > /dev/null 2>&1; then
            log_info "停止 $service_name (PID: $pid)..."
            kill $pid
            sleep 2
            
            # 如果进程仍在运行，强制杀死
            if ps -p $pid > /dev/null 2>&1; then
                log_warning "强制停止 $service_name..."
                kill -9 $pid
            fi
            
            log_success "$service_name 已停止"
        else
            log_warning "$service_name 进程已不存在"
        fi
        rm -f "$pid_file"
    else
        log_warning "未找到 $service_name 的PID文件"
    fi
}

# 停止端口上的进程
stop_port() {
    local port=$1
    local service_name=$2
    
    local pids=$(lsof -ti:$port 2>/dev/null)
    if [ -n "$pids" ]; then
        log_info "停止端口 $port 上的 $service_name 进程..."
        echo $pids | xargs kill -9 2>/dev/null || true
        log_success "端口 $port 上的进程已停止"
    else
        log_info "端口 $port 上没有运行的进程"
    fi
}

# 主函数
main() {
    echo "🛑 停止选课社区服务..."
    echo ""
    
    # 停止前端服务
    log_info "停止前端服务..."
    stop_process "frontend.pid" "前端服务"
    stop_port 3000 "前端"
    
    # 停止后端服务
    log_info "停止后端服务..."
    stop_process "backend.pid" "后端服务"
    stop_port 8000 "后端"
    
    # 可选：停止数据库服务
    echo ""
    read -p "是否停止数据库服务 (PostgreSQL 和 Redis)? [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "停止数据库服务..."
        
        # 停止 PostgreSQL
        if brew services list | grep -q "postgresql@15.*started"; then
            log_info "停止 PostgreSQL..."
            brew services stop postgresql@15
            log_success "PostgreSQL 已停止"
        else
            log_info "PostgreSQL 未在运行"
        fi
        
        # 停止 Redis
        if brew services list | grep -q "redis.*started"; then
            log_info "停止 Redis..."
            brew services stop redis
            log_success "Redis 已停止"
        else
            log_info "Redis 未在运行"
        fi
    else
        log_info "保持数据库服务运行"
    fi
    
    echo ""
    echo "=================================================="
    echo "✅ 选课社区服务已停止！"
    echo "=================================================="
    echo ""
    echo "🔄 重新启动服务:"
    echo "   bash start_jcourse.sh"
    echo ""
    echo "=================================================="
    echo ""
}

# 运行主函数
main "$@" 