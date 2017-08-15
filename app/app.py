#!/usr/bin/env python3

import boto3
import connexion
import logging
import uuid
import os
import requests

from flask import abort, g

from boto3.dynamodb.conditions import Key

from os.path import join, dirname
from dotenv import load_dotenv

#
#  app.py
#  UserManager
#
#  Copyright © 2017 NGINX Inc. All rights reserved.
#

dotenv_path = join(dirname(__file__), '.env')
load_dotenv(dotenv_path)
db_endpoint = os.environ.get('DB_ENDPOINT')


def healthcheck():
    return '', 204


def get_db():
    if __name__ == '__main__':
        db = getattr(g, '_database', None)
        if db is None:
            db = g._database = boto3.resource('dynamodb', endpoint_url=db_endpoint)
    else:
        db = boto3.resource('dynamodb', endpoint_url=db_endpoint)
    return db

try:
    client = boto3.client('dynamodb', endpoint_url=db_endpoint)
    response = client.describe_table(TableName='users')
except:
    table = get_db().create_table(
        TableName='users',
        KeySchema=[
            {
                'AttributeName': 'id',
                'KeyType': 'HASH'
            }
        ],
        AttributeDefinitions=[
            {
                'AttributeName': 'id',
                'AttributeType': 'S'
            },
            {
                'AttributeName': 'google_id',
                'AttributeType': 'S'
            },
            {
                'AttributeName': 'facebook_id',
                'AttributeType': 'S'
            }
        ],
        GlobalSecondaryIndexes=[
            {
                'IndexName': 'google_id-index',
                'KeySchema': [
                    {
                        'AttributeName': 'google_id',
                        'KeyType': 'HASH'
                    },
                ],
                'Projection': {
                    'ProjectionType': 'ALL',
                },
                'ProvisionedThroughput': {
                    'ReadCapacityUnits': 5,
                    'WriteCapacityUnits': 5
                }
            },
            {
                'IndexName': 'facebook_id-index',
                'KeySchema': [
                    {
                        'AttributeName': 'facebook_id',
                        'KeyType': 'HASH'
                    },
                ],
                'Projection': {
                    'ProjectionType': 'ALL',
                },
                'ProvisionedThroughput': {
                    'ReadCapacityUnits': 5,
                    'WriteCapacityUnits': 5
                }
            }
        ],
        ProvisionedThroughput={
            'ReadCapacityUnits': 5,
            'WriteCapacityUnits': 5
        }
    )

    table.meta.client.get_waiter('table_exists').wait(TableName='users')


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

    url = os.environ.get('ALBUM_MANAGER_URL')
    headers = {'Auth-ID': body['id']}

    data = {'album[name]': 'Profile Pictures', 'album[state]': 'active'}
    r = requests.post(url, headers=headers, data=data)
    pp_r = r.json()

    data = {'album[name]': 'Cover Pictures', 'album[state]': 'active'}
    r = requests.post(url, headers=headers, data=data)
    cv_r = r.json()

    body_albums_ids = {'profile_pictures_id': str(pp_r['id']), 'cover_pictures_id': str(cv_r['id']), 'profile_picture_url': 'generic'}
    update_user(body['id'], body_albums_ids)

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
    if get_user_by_id(id):
        return get_users_table().delete_item(Key={'id': id})


logging.basicConfig(level=logging.DEBUG)
app = connexion.App(__name__)
app.add_api('swagger.yaml')
application = app.app

if __name__ == '__main__':
    app.run(port=8080, debug=True)
