import boto3
import botocore
import os
import logging

from flask import abort, g

#
# Get the DB address as a string from an environment variable
#
db_endpoint = os.environ.get('DB_ENDPOINT')

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

get_users_table()