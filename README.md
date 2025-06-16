# 🎓 西南财经大学选课评价社区

一个现代化的选课评价系统，为西南财经大学学生提供课程信息查询、评价分享和学习交流的平台。

## 🌟 项目特色

- 📚 **课程信息查询** - 完整的课程数据库，包含课程代码、名称、教师、学分等详细信息
- ⭐ **课程评价系统** - 学生可以对已修课程进行评价和打分
- 🔍 **智能搜索** - 支持按课程名称、教师、院系等多维度搜索
- 👥 **社区交流** - 学生可以分享学习心得和课程体验
- 📱 **响应式设计** - 支持手机、平板、电脑等多种设备访问

## 🛠️ 技术栈

### 后端
- **Django 4.2.23** - Python Web框架
- **Django REST Framework** - API开发框架
- **PostgreSQL** - 主数据库
- **Redis** - 缓存和会话存储
- **Gunicorn** - WSGI服务器

### 前端
- **Next.js 13** - React全栈框架
- **React 18** - 用户界面库
- **Ant Design** - UI组件库
- **TypeScript** - 类型安全的JavaScript

### 部署
- **Nginx** - 反向代理和静态文件服务
- **Let's Encrypt** - SSL证书
- **systemd** - 服务管理
- **Ubuntu 22.04** - 服务器操作系统

## 🚀 快速启动

### 本地开发环境

1. **克隆项目**
   ```bash
   git clone https://github.com/harry51888/SWUFE.git
   cd SWUFE
   ```

2. **启动服务**
   ```bash
   bash 启动选课社区.sh
   ```

3. **访问应用**
   - 前端界面: http://localhost:3000
   - 后端API: http://localhost:8000
   - 管理后台: http://localhost:8000/admin

### 生产环境部署

1. **打包项目文件**
   ```bash
   bash 打包项目文件.sh
   ```

2. **上传到服务器**
   ```bash
   bash 一键部署到服务器.sh
   ```

3. **服务器端部署**
   ```bash
   # 在服务器上执行
   sudo su -
   cd /opt/jcourse
   bash 生产环境部署脚本.sh
   ```

## 📊 项目结构

```
SWUFE/
├── jcourse_api-master/          # Django后端
│   ├── jcourse/                 # 主应用
│   ├── requirements_compatible.txt # Python依赖
│   └── manage.py               # Django管理脚本
├── jcourse-master/             # Next.js前端
│   ├── src/                    # 源代码
│   ├── public/                 # 静态资源
│   └── package.json           # Node.js依赖
├── class-resource/             # 课程数据
│   └── 课表.csv               # 课程信息CSV文件
├── 启动选课社区.sh            # 本地启动脚本
├── 停止选课社区.sh            # 本地停止脚本
├── 生产环境部署脚本.sh        # 生产环境部署脚本
└── 生产环境部署指南.md        # 详细部署文档
```

## 🔧 开发指南

### 后端开发
```bash
cd jcourse_api-master
python3 -m venv venv
source venv/bin/activate
pip install -r requirements_compatible.txt
python manage.py runserver
```

### 前端开发
```bash
cd jcourse-master
yarn install
yarn dev
```

### 数据库管理
```bash
# 创建迁移
python manage.py makemigrations

# 执行迁移
python manage.py migrate

# 导入课程数据
python manage.py import_schedule class-resource/课表.csv
```

## 🌐 在线访问

- **生产环境**: https://swufe.kaixuebang.com
- **管理后台**: https://swufe.kaixuebang.com/admin

## 👤 默认账户

- **用户名**: admin
- **密码**: admin123456

## 📝 功能特性

### 学生功能
- ✅ 浏览课程信息
- ✅ 搜索课程和教师
- ✅ 查看课程评价
- ✅ 提交课程评价
- ✅ 个人学习记录

### 管理员功能
- ✅ 课程信息管理
- ✅ 用户管理
- ✅ 评价内容审核
- ✅ 系统数据统计

## 🔒 安全特性

- HTTPS强制重定向
- CSRF保护
- XSS防护
- SQL注入防护
- 用户认证和授权
- 敏感信息加密

## 📈 性能优化

- Redis缓存加速
- 静态文件CDN
- 数据库查询优化
- 前端代码分割
- Gzip压缩

## 🤝 贡献指南

1. Fork本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📞 联系方式

- **开发者**: harry51888
- **邮箱**: harry51888@github.com
- **项目地址**: https://github.com/harry51888/SWUFE

## 🙏 致谢

感谢西南财经大学提供的课程数据支持，以及所有参与测试和反馈的同学们。

---

**⭐ 如果这个项目对您有帮助，请给个Star支持一下！** 