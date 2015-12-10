#!/usr/bin/env python3

import boto3
import connexion
import logging
import uuid

from flask import abort, g

from boto3.dynamodb.conditions import Key

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

def get_user_by_index_and_key(index, key, id):
    response = get_users_table().query(
        IndexName=index,
        KeyConditionExpression=Key(key).eq(id)
    )

    if not response['Items']:
        abort(404)

    item = response['Items'][0]
    return item

def create_user(body) -> str:
    body['id'] = str(uuid.uuid4())

    get_users_table().put_item(Item=body)

    return body

def get_user_by_id(id) -> str:
    response = get_users_table().get_item(Key={'id': id})

    if 'Item' not in response:
        abort(404)

    return response['Item']

def get_user_by_facebook_id(id) -> str:
    return get_user_by_index_and_key('facebook_id-index', 'facebook_id', id)

def get_user_by_google_id(id) -> str:
    return get_user_by_index_and_key('google_id-index', 'google_id', id)

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