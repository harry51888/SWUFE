#!/bin/bash

# 🚀 一键部署到Ubuntu服务器
SERVER="ubuntu@101.36.111.202"
PACKAGE=$(ls jcourse_production_*.tar.gz | head -1)

echo "🚀 开始部署选课社区到生产服务器..."
echo "📦 上传文件: $PACKAGE"
echo "🌐 目标服务器: $SERVER"
echo ""

# 检查文件是否存在
if [ ! -f "$PACKAGE" ]; then
    echo "❌ 未找到打包文件，请先运行: bash 打包项目文件.sh"
    exit 1
fi

# 上传文件
echo "📤 上传项目文件到服务器..."
scp $PACKAGE $SERVER:/tmp/

echo ""
echo "🔧 请在另一个终端窗口执行以下命令完成部署："
echo ""
echo "ssh $SERVER"
echo "sudo su -"
echo "cd /tmp"
echo "tar -xzf jcourse_production_*.tar.gz"
echo "mv jcourse_production_* /opt/jcourse"
echo "cd /opt/jcourse"
echo "chmod +x 生产环境部署脚本.sh"
echo "bash 生产环境部署脚本.sh"
echo ""
echo "🎉 部署完成后访问："
echo "🌐 网站: https://swufe.kaixuebang.com"
echo "👤 管理后台: https://swufe.kaixuebang.com/admin"
echo "📋 账户: admin / admin123456" 