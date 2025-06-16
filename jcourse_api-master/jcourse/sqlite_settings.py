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
