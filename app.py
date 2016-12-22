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

dotenv_path = join(dirname(__file__), '.env')
load_dotenv(dotenv_path)


def healthcheck():
    return '', 204


def get_db():
    if __name__ == '__main__':
        db = getattr(g, '_database', None)
        if db is None:
            db = g._database = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION'))
    else:
        db = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION'))
    return db


def get_users_table():
    return get_db().Table('users')  # dynamodb.Table(name='users')


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

    url = 'http://album-manager.mra.nginxps.com/albums'
    headers = {'Auth-ID': body['id']}

    data = {'album[name]': 'Profile Pictures'}
    r = requests.post(url, headers=headers, data=data)
    pp_r = r.json()

    data = {'album[name]': 'Cover Pictures'}
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
        get_users_table().delete_item(Key={'id': id})


logging.basicConfig(level=logging.DEBUG)
app = connexion.App(__name__)
app.add_api('swagger.yaml')
application = app.app

if __name__ == '__main__':
    app.run(port=8080, debug=True)
