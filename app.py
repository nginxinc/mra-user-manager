#!/usr/bin/env python3

import boto3
import connexion
import logging
import json

from flask import abort, g

from os.path import join, dirname
from dotenv import load_dotenv

dotenv_path = join(dirname(__file__), '.env')
load_dotenv(dotenv_path)

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = boto3.resource('dynamodb')
    return db

def get_users_table():
    return get_db().Table('users')

def create_user(body) -> str:
    return get_users_table().put_item(Item=body)

def get_user_by_id(id) -> str:
    response = get_users_table().get_item(Key={'id': id})

    if 'Item' not in response:
        abort(404)

    return response['Item']

def update_user(id, body) -> str:
    item = get_user_by_id(id)

    for key, value in body.items():
        item[key] = value

    get_users_table().put_item(Item=item)

    return item

def delete_user(id) -> str:
    get_users_table().delete_item(Key={'id': id})

logging.basicConfig(level=logging.DEBUG)
app = connexion.App(__name__)
app.add_api('swagger.yaml')
application = app.app

if __name__ == '__main__':
    app.run(port=8080, debug=True)