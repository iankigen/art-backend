# Generated by Django 2.0.1 on 2018-03-20 10:54

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0008_auto_20180320_0441'),
    ]

    operations = [
        migrations.RenameField(
            model_name='item',
            old_name='user_id',
            new_name='assigned_to',
        ),
    ]
