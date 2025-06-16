import csv
import re
from django.core.management import BaseCommand
from django.db import transaction
from jcourse_api.models import Course, Teacher, Department, Category, Semester
from pypinyin import lazy_pinyin, Style


class Command(BaseCommand):
    help = '导入课表CSV文件'

    def add_arguments(self, parser):
        parser.add_argument('csv_file', type=str, help='CSV文件路径')
        parser.add_argument('--semester', type=str, default='2024-2025-2', help='学期名称')

    def handle(self, *args, **options):
        csv_file = options['csv_file']
        semester_name = options['semester']
        
        # 创建或获取学期
        semester, created = Semester.objects.get_or_create(
            name=semester_name,
            defaults={'available': True}
        )
        if created:
            self.stdout.write(f'创建学期: {semester_name}')
        
        # 读取CSV文件，处理UTF-8 BOM
        with open(csv_file, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            
            created_courses = 0
            updated_courses = 0
            
            with transaction.atomic():
                for row in reader:
                    try:
                        # 解析CSV数据
                        course_code = row['课程代码'].strip()
                        course_name = row['课程名称'].strip()
                        course_name_en = row['课程英文名称'].strip() if row['课程英文名称'] else ''
                        course_type = row['课程性质'].strip()
                        department_name = row['开课学院'].strip()
                        teacher_names = row['任课老师'].strip()
                        credit = float(row['学分']) if row['学分'] else 0.0
                        
                        # 创建或获取院系
                        department, _ = Department.objects.get_or_create(
                            name=department_name
                        )
                        
                        # 创建或获取课程类别
                        category, _ = Category.objects.get_or_create(
                            name=course_type
                        )
                        
                        # 处理教师信息（可能有多个教师，用/分隔）
                        teacher_list = [name.strip() for name in teacher_names.split('/')]
                        main_teacher_name = teacher_list[0]
                        
                        # 创建或获取主讲教师
                        main_teacher = self.get_or_create_teacher(
                            main_teacher_name, department, semester
                        )
                        
                        # 创建或更新课程
                        course, course_created = Course.objects.get_or_create(
                            code=course_code,
                            main_teacher=main_teacher,
                            defaults={
                                'name': course_name,
                                'credit': credit,
                                'department': department,
                                'last_semester': semester,
                            }
                        )
                        
                        if course_created:
                            created_courses += 1
                            self.stdout.write(f'创建课程: {course_code} {course_name}')
                        else:
                            # 更新课程信息
                            course.name = course_name
                            course.credit = credit
                            course.department = department
                            course.last_semester = semester
                            course.save()
                            updated_courses += 1
                        
                        # 添加课程类别
                        course.categories.add(category)
                        
                        # 添加所有教师到教师组
                        for teacher_name in teacher_list:
                            teacher = self.get_or_create_teacher(
                                teacher_name, department, semester
                            )
                            course.teacher_group.add(teacher)
                            
                    except Exception as e:
                        self.stdout.write(
                            self.style.ERROR(f'处理行时出错: {row}')
                        )
                        self.stdout.write(self.style.ERROR(f'错误: {str(e)}'))
                        continue
        
        self.stdout.write(
            self.style.SUCCESS(f'导入完成! 创建 {created_courses} 门课程，更新 {updated_courses} 门课程')
        )

    def get_or_create_teacher(self, name, department, semester):
        """创建或获取教师"""
        # 生成拼音
        pinyin_list = lazy_pinyin(name, style=Style.NORMAL)
        pinyin = ''.join(pinyin_list)
        abbr_pinyin = ''.join([py[0] for py in pinyin_list])
        
        teacher, created = Teacher.objects.get_or_create(
            name=name,
            defaults={
                'department': department,
                'pinyin': pinyin,
                'abbr_pinyin': abbr_pinyin,
                'last_semester': semester,
            }
        )
        
        if not created:
            # 更新最后学期
            teacher.last_semester = semester
            teacher.save()
        
        return teacher 