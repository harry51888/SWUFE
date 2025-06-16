#!/bin/bash

# 📚 选课社区一键停止脚本
# 适用于快速停止所有相关服务

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

# 显示停止横幅
show_banner() {
    echo -e "${RED}"
    echo "=================================================="
    echo "🛑 西南财经大学选课评价社区"
    echo "🔥 一键停止脚本"
    echo "=================================================="
    echo -e "${NC}"
}

# 停止PID文件中的进程
stop_pid_process() {
    local pid_file=$1
    local service_name=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p $pid > /dev/null 2>&1; then
            log_info "停止 $service_name (PID: $pid)..."
            kill $pid 2>/dev/null
            sleep 3
            
            # 如果进程仍在运行，强制杀死
            if ps -p $pid > /dev/null 2>&1; then
                log_warning "强制停止 $service_name..."
                kill -9 $pid 2>/dev/null
            fi
            
            log_success "$service_name 已停止"
        else
            log_warning "$service_name 进程已不存在"
        fi
        rm -f "$pid_file"
    else
        log_warning "未找到 $service_name 的PID文件: $pid_file"
    fi
}

# 停止端口上的所有进程
stop_port_processes() {
    local port=$1
    local service_name=$2
    
    log_info "检查端口 $port 上的进程..."
    local pids=$(lsof -ti:$port 2>/dev/null)
    
    if [ -n "$pids" ]; then
        log_info "停止端口 $port 上的 $service_name 进程..."
        echo $pids | xargs kill -9 2>/dev/null || true
        sleep 1
        
        # 再次检查
        local remaining_pids=$(lsof -ti:$port 2>/dev/null)
        if [ -z "$remaining_pids" ]; then
            log_success "端口 $port 上的进程已全部停止"
        else
            log_warning "端口 $port 上仍有进程运行"
        fi
    else
        log_info "端口 $port 上没有运行的进程"
    fi
}

# 停止相关的Node.js和Python进程
stop_related_processes() {
    log_step "停止相关进程..."
    
    # 停止包含特定关键词的进程
    local keywords=("next dev" "manage.py runserver" "yarn dev" "django")
    
    for keyword in "${keywords[@]}"; do
        log_info "查找并停止包含 '$keyword' 的进程..."
        local pids=$(ps aux | grep "$keyword" | grep -v grep | awk '{print $2}' 2>/dev/null)
        
        if [ -n "$pids" ]; then
            echo $pids | xargs kill -9 2>/dev/null || true
            log_success "已停止 '$keyword' 相关进程"
        fi
    done
}

# 清理临时文件
cleanup_files() {
    log_step "清理临时文件..."
    
    # 清理日志文件（可选）
    local files_to_clean=("backend.pid" "frontend.pid")
    
    for file in "${files_to_clean[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log_info "已删除 $file"
        fi
    done
    
    # 询问是否清理日志文件
    echo ""
    read -p "是否清理日志文件 (backend.log, frontend.log)? [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f backend.log frontend.log
        log_success "日志文件已清理"
    else
        log_info "保留日志文件"
    fi
}

# 显示服务状态
show_service_status() {
    log_step "检查服务状态..."
    
    echo ""
    echo -e "${CYAN}📊 当前端口状态:${NC}"
    
    # 检查前端端口 3000
    if lsof -i :3000 >/dev/null 2>&1; then
        echo -e "   ${RED}❌ 端口 3000: 仍有进程运行${NC}"
    else
        echo -e "   ${GREEN}✅ 端口 3000: 已释放${NC}"
    fi
    
    # 检查后端端口 8000
    if lsof -i :8000 >/dev/null 2>&1; then
        echo -e "   ${RED}❌ 端口 8000: 仍有进程运行${NC}"
    else
        echo -e "   ${GREEN}✅ 端口 8000: 已释放${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📁 PID文件状态:${NC}"
    
    if [ -f "backend.pid" ]; then
        echo -e "   ${YELLOW}⚠️  backend.pid: 存在${NC}"
    else
        echo -e "   ${GREEN}✅ backend.pid: 已清理${NC}"
    fi
    
    if [ -f "frontend.pid" ]; then
        echo -e "   ${YELLOW}⚠️  frontend.pid: 存在${NC}"
    else
        echo -e "   ${GREEN}✅ frontend.pid: 已清理${NC}"
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${GREEN}=================================================="
    echo "✅ 选课社区服务已完全停止！"
    echo "=================================================="
    echo -e "${NC}"
    echo -e "${CYAN}🔄 重新启动服务:${NC}"
    echo "   bash 启动选课社区.sh"
    echo ""
    echo -e "${CYAN}📋 查看日志:${NC}"
    echo "   tail -f backend.log"
    echo "   tail -f frontend.log"
    echo ""
    echo -e "${CYAN}🗂️  管理数据库:${NC}"
    echo "   cd jcourse_api-master"
    echo "   source venv/bin/activate"
    echo "   python manage.py shell --settings=jcourse.sqlite_settings"
    echo ""
    echo -e "${GREEN}=================================================="
    echo -e "${NC}"
}

# 主函数
main() {
    show_banner
    
    # 停止PID文件中的进程
    log_step "停止主要服务..."
    stop_pid_process "frontend.pid" "前端服务"
    stop_pid_process "backend.pid" "后端服务"
    
    # 停止端口上的进程
    log_step "停止端口服务..."
    stop_port_processes 3000 "前端"
    stop_port_processes 8000 "后端"
    
    # 停止相关进程
    stop_related_processes
    
    # 等待一下确保进程完全停止
    sleep 2
    
    # 清理文件
    cleanup_files
    
    # 显示服务状态
    show_service_status
    
    # 显示完成信息
    show_completion
}

# 处理中断信号
trap 'echo -e "\n${YELLOW}停止操作被中断${NC}"; exit 1' INT TERM

# 执行主函数
main "$@" 