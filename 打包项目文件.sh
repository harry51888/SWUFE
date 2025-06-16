#!/bin/bash

# 📦 选课社区项目文件打包脚本
# 用于准备生产环境部署文件

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}📦 正在打包选课社区项目文件...${NC}"

# 创建临时目录
TEMP_DIR="jcourse_production_$(date +%Y%m%d_%H%M%S)"
mkdir -p $TEMP_DIR

echo -e "${BLUE}[INFO]${NC} 复制项目文件..."

# 复制后端文件
if [ -d "jcourse_api-master" ]; then
    cp -r jcourse_api-master $TEMP_DIR/
    echo -e "${GREEN}✅${NC} 后端文件已复制"
else
    echo -e "${YELLOW}⚠️${NC} 未找到后端目录 jcourse_api-master"
fi

# 复制前端文件
if [ -d "jcourse-master" ]; then
    cp -r jcourse-master $TEMP_DIR/
    # 删除前端的node_modules和.next目录
    rm -rf $TEMP_DIR/jcourse-master/node_modules
    rm -rf $TEMP_DIR/jcourse-master/.next
    echo -e "${GREEN}✅${NC} 前端文件已复制 (已排除node_modules和.next)"
else
    echo -e "${YELLOW}⚠️${NC} 未找到前端目录 jcourse-master"
fi

# 复制课程数据
if [ -d "class-resource" ]; then
    cp -r class-resource $TEMP_DIR/
    echo -e "${GREEN}✅${NC} 课程数据已复制"
else
    echo -e "${YELLOW}⚠️${NC} 未找到课程数据目录 class-resource"
fi

# 复制部署脚本
cp 生产环境部署脚本.sh $TEMP_DIR/
echo -e "${GREEN}✅${NC} 部署脚本已复制"

# 创建部署说明文件
cat > $TEMP_DIR/README_DEPLOY.md << 'EOF'
# 生产环境部署说明

## 📋 部署步骤

1. **上传文件到服务器**
   ```bash
   # 在本地执行
   scp -r jcourse_production_* ubuntu@101.36.111.202:/tmp/
   ```

2. **连接服务器**
   ```bash
   ssh ubuntu@101.36.111.202
   ```

3. **切换到root用户**
   ```bash
   sudo su -
   ```

4. **移动文件到项目目录**
   ```bash
   mv /tmp/jcourse_production_* /opt/jcourse
   cd /opt/jcourse
   ```

5. **运行部署脚本**
   ```bash
   chmod +x 生产环境部署脚本.sh
   bash 生产环境部署脚本.sh
   ```

## 🌐 访问信息

- **网站地址**: https://swufe.kaixuebang.com
- **管理后台**: https://swufe.kaixuebang.com/admin
- **默认账户**: admin / admin123456

## 📊 服务管理

```bash
# 查看服务状态
systemctl status jcourse-backend
systemctl status jcourse-frontend
systemctl status nginx

# 重启服务
systemctl restart jcourse-backend
systemctl restart jcourse-frontend

# 查看日志
tail -f /opt/jcourse/logs/django.log
tail -f /opt/jcourse/logs/gunicorn_error.log
```

## 🔧 故障排除

1. **域名解析**: 确保域名 swufe.kaixuebang.com 解析到服务器IP
2. **防火墙**: 确保80和443端口开放
3. **SSL证书**: 如果证书获取失败，检查域名解析是否正确
EOF

echo -e "${GREEN}✅${NC} 部署说明已创建"

# 创建压缩包
tar -czf $TEMP_DIR.tar.gz $TEMP_DIR
echo -e "${GREEN}✅${NC} 压缩包已创建: $TEMP_DIR.tar.gz"

# 显示文件信息
echo ""
echo -e "${BLUE}📊 打包完成信息:${NC}"
echo "压缩包: $TEMP_DIR.tar.gz"
echo "大小: $(du -h $TEMP_DIR.tar.gz | cut -f1)"
echo ""

echo -e "${BLUE}📋 上传命令:${NC}"
echo "scp $TEMP_DIR.tar.gz ubuntu@101.36.111.202:/tmp/"
echo ""

echo -e "${BLUE}📋 服务器端解压命令:${NC}"
echo "cd /tmp"
echo "tar -xzf $TEMP_DIR.tar.gz"
echo "sudo mv $TEMP_DIR /opt/jcourse"
echo ""

# 清理临时目录
rm -rf $TEMP_DIR

echo -e "${GREEN}🎉 项目文件打包完成！${NC}" 