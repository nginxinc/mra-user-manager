#!/usr/bin/env python3

import boto3
import botocore
import connexion
import logging
import uuid
import os
import requests

from flask import abort, g

from boto3.dynamodb.conditions import Key

from os.path import join, dirname
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash, check_password_hash

#
#  app.py
#  UserManager
#
#  Copyright © 2017 NGINX Inc. All rights reserved.
#

#
# The User Manager service supports .env files. You can create a file named .env in the app directory
# in order to set environment variables for the app
#
dotenv_path = join(dirname(__file__), '.env')
load_dotenv(dotenv_path)

#
# Get the DB address as a string from an environment variable
#
db_endpoint = os.environ.get('DB_ENDPOINT')

#
# For development, set an environment variable to disable HTTPS certificate verification
#
verify_certs = os.environ.get('VERIFY_CERTS') != 'False'


#
# Defines the healthcheck endpoint to ensure that the service is running
#
def healthcheck():
    return '', 204


#
# Get the database based on the db_endpoint variable set from the DB_ENDPOINT environment variable
#
def get_db():
    if __name__ == '__main__':
        db = getattr(g, '_database', None)
        if db is None:
            db = g._database = boto3.resource('dynamodb', region_name='us-west-1', endpoint_url=db_endpoint)
    else:
        db = boto3.resource('dynamodb', region_name='us-west-1', endpoint_url=db_endpoint)
    return db


#
# Get the users table from the database
# TODO: This is a hack. We will clean this up in v2. For the purposes of a
# reference application, we check for the able and create it if it doesn't
# exist. Production grade services should remove this logic in favor of
# a proper script to create the table
#
def get_users_table():

    client = get_db()
    try:
        table = client.create_table(
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
                },
                {
                    'AttributeName': 'local_id',
                    'AttributeType': 'S'
                },
                {
                    'AttributeName': 'email',
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
                },
                {
                    'IndexName': 'email_address-index',
                    'KeySchema': [
                        {
                            'AttributeName': 'email',
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
                    'IndexName': 'local_id-index',
                    'KeySchema': [
                        {
                            'AttributeName': 'local_id',
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

        logging.debug("+++++++++ table: " + str(table))

        if table is not None and len(table) > 0:
            table.meta.client.get_waiter('table_exists').wait(TableName='users')
            
    except Exception as e:
        logging.error('===== error is', e)

        if e is AttributeError:
            logging.error('++++++ attribute error', e);

        if e is botocore.exceptions.ClientError and 'Error' in e.response and \
                e.response['Error']['Code'] == 'ResourceInUseException':
            logging.debug('======= looking for users table: already exists')
        else:
            logging.error('Unable to process error', e)

    return client.Table('users')


#
# Get the user with the key and ID from the index
# @param index: the index to use when searching for the user it should be one of:
#        - email_address-index
#        - facebook_id-index
#        - google_id-index
#        - local_id-index
# @param key: the name of the key to use when searching the index
# @param id: the ID of the item to find
#
def get_user_by_index_and_key(index, key, id):
    user_response = get_users_table().query(
        IndexName=index,
        KeyConditionExpression=Key(key).eq(id)
    )

    if not user_response['Items']:
        return None

    item = user_response['Items'][0]
    return item


#
# Create a user with the values provided in the in the body parameter. Also
#          creates default albums for profile pictures and cover pictures
#
# @param body: contains the values for creating a user:
#         - auth_id
#         - auth_provider
#         - email_address
#
def create_user(body) -> str:
    body['id'] = str(uuid.uuid4())

    # set the password and local_id if the body dictionary contains an entry named password
    if 'password' in body:
        body['local_id'] = str(uuid.uuid4())
        body['password'] = generate_password_hash(body['password'])

    # insert the user record in to the table
    get_users_table().put_item(Item=body)

    url = os.environ.get('ALBUM_MANAGER_URL')
    headers = {'Auth-ID': body['id']}

    # Call the album manager to create the Profile Pictures album
    data = {'album[name]': 'Profile Pictures', 'album[state]': 'active'}
    r = requests.post(url, headers=headers, data=data, verify=verify_certs)
    pp_r = r.json()

    # Call the album manager to create the Cover Pictures album
    data = {'album[name]': 'Cover Pictures', 'album[state]': 'active'}
    r = requests.post(url, headers=headers, data=data, verify=verify_certs)
    cv_r = r.json()

    # set parameters in the body dictionary and update the user entry in the
    # user table
    body_albums_ids = {'profile_pictures_id': str(pp_r['id']), 'cover_pictures_id': str(cv_r['id']),
                       'profile_picture_url': 'generic'}
    body = update_user(body['id'], body_albums_ids)

    return body


#
# Find the user by the ID generated in create_user
# @param id: the ID of the user to find
#
def get_user_by_id(id) -> str:
    response = get_users_table().get_item(Key={'id': id})

    if 'Item' not in response:
        abort(404)

    return response['Item']


#
# Find the user by the facebook ID
# @param id: the facebook_id of the user to find
#
def get_user_by_facebook_id(id) -> str:
    result = get_user_by_index_and_key('facebook_id-index', 'facebook_id', id)

    if result is None:
        abort(404)

    return result


#
# Find the user by the Google ID
# @param id: the google_id of the user to find
#
def get_user_by_google_id(id) -> str:
    result = get_user_by_index_and_key('google_id-index', 'google_id', id)

    if result is None:
        abort(404)

    return result


#
# Find a user by the local_id
# @param id: the local ID of the user to find
#
def get_user_by_local_id(id) -> str:
    result = get_user_by_index_and_key('local_id-index', 'local_id', id)

    if result is None:
        abort(404)

    return result


#
# Find a user by their email address
# @param email: the email address of the user to find
#
def get_user_by_email(email) -> str:
    result = get_user_by_index_and_key('email_address-index', 'email', email)

    if result is None:
        result = {'found': False}

    return result


#
# Authenticate a local user by comparing the password hash using methods in
#           the werkzeug library
#
# @param body: the POST request body
#
def auth_local_user(body) -> str:
    email = body['email']
    password = body['password']

    if email and password:
        user = get_user_by_email(email)
        if user:
            body['authenticated'] = check_password_hash(user['password'], password)

    return body


#
# Update the user with the data provided
#
# @param id: the ID of the user to update
# @param body: the post data to use when updating the user
#
def update_user(id, body) -> str:
    item = get_user_by_id(id)

    for key, value in body.items():
        item[key] = value

    get_users_table().put_item(Item=item)
    return item


#
# Permanently deletes a user by their ID
# @param id: the ID of the user to delete
#
def delete_user(id) -> str:
    if get_user_by_id(id):
        return get_users_table().delete_item(Key={'id': id})


#
# Initialize the application, logging, and swagger definition
#
logging.basicConfig(level=logging.DEBUG)
app = connexion.App(__name__)
app.add_api('swagger.yaml')
application = app.app

if __name__ == '__main__':
    app.run(port=8080, debug=True)
