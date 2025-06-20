# Generated by Django 4.0.3 on 2022-03-03 19:00
from django.contrib.auth.models import User
from django.db import migrations
from django.db.models import F

from jcourse_api.models import Review, UserPoint
from jcourse_api.utils.point import get_user_point_with_reviews
from jcourse_api.views import get_user_point


def get_old_point(user: User):
    reviews = Review.objects.filter(user=user)
    return get_user_point_with_reviews(user, reviews)


def make_up_old_point(apps, schema_editor):
    # 为了SQLite兼容性，跳过这个数据处理步骤
    # 这个迁移是为了处理历史数据的积分补偿，新部署可以跳过
    pass


class Migration(migrations.Migration):
    dependencies = [
        ('jcourse_api', '0021_semester_available'),
    ]

    operations = [
        migrations.RunPython(make_up_old_point),
    ]
