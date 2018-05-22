#!/bin/bash

set -o errexit
set -o pipefail

python manage.py makemigrations
python manage.py migrate
coverage run --source api manage.py test -v 2
coveralls


exec $@