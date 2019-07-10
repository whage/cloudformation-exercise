#!/bin/sh

cd /webapp
source env/bin/activate

export FLASK_APP=main.py
flask run
