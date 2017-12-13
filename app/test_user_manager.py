from unittest import TestCase

from werkzeug.exceptions import NotFound

from mock import patch
from os.path import join, dirname
from dotenv import load_dotenv

import boto3

from requests.models import Response

dotenv_path = join(dirname(__file__), '.env_test')
load_dotenv(dotenv_path)

from app import create_user, get_user_by_id, get_user_by_facebook_id, get_user_by_google_id, delete_user, \
    get_users_table, update_user, get_db

class TestCreateUser(TestCase):
    body = {'google_id': 'GOOGLE_ID', 'email': 'EMAIL', 'facebook_id': 'FACEBOOK_ID', 'name': 'NAME'}

    def side_effect_func(method, arguments):
        if (method == 'GetItem'):
            return {'Item': {'profile_pictures_id': '168', 'google_id': 'GOOGLE_ID', 'facebook_id': 'FACEBOOK_ID', 'email': 'EMAIL',
                'profile_picture_url': 'generic', 'id': arguments['Key']['id'], 'name': 'NAME', 'cover_pictures_id': '169'}}

    def create_resource():
        return boto3.resource('dynamodb', region_name='us-west-1')

    def post_request(url, data, headers, verify):
        the_response = Response()
        the_response.status_code = 201
        the_response._content = b'{"id":0}'
        return the_response

    @patch('requests.post', side_effect=post_request)
    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=side_effect_func)
    def test_create_user(self, mock_api_call, mock_get_db, mock_post, body=body):
        create_user(body)
        user = get_user_by_id(body['id'])
        body['profile_picture_url'] = 'generic'
        body['profile_pictures_id'] = user['profile_pictures_id']
        body['cover_pictures_id'] = user['cover_pictures_id']
        self.assertEquals(get_user_by_id(body['id']), body)

class TestGetUserById(TestCase):
    body = {'google_id': 'GOOGLE_ID', 'email': 'EMAIL', 'facebook_id': 'FACEBOOK_ID', 'name': 'NAME', 
        'id': 'testGetUser'}

    def side_effect_func(method, arguments):
        if (method == 'GetItem'):
            if (arguments['Key']['id'] == "testGetUser"):
                return {'Item': {'google_id': 'GOOGLE_ID', 'email': 'EMAIL', 'facebook_id': 'FACEBOOK_ID', 'name': 'NAME',
                    'id': 'testGetUser'}}
            else:
                raise NotFound

    def create_resource():
        return boto3.resource('dynamodb')

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=side_effect_func)
    def test_get_user(self, mock_api_call, mock_get_db, body=body):
        self.assertEquals(get_user_by_id('testGetUser'), body)

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=side_effect_func)
    def test_get_nonexistent_user(self, mock_api_call, mock_get_db):
        with self.assertRaises(NotFound):
            get_user_by_id('FAKE_ID')


class TestGetUserByFacebookId(TestCase):
    body = {'facebook_id': 'FACEBOOK_ID', 'name': 'T_FACEBOOK', 'id': 'testGetFacebookUser'}

    def side_effect_func(method, arguments):
        if (method == 'Query'):
            return {'Items': [{'name': 'T_FACEBOOK', 'facebook_id': 'FACEBOOK_ID', 'id': 'testGetFacebookUser'}]}

    def not_found(method, arguments):
        raise NotFound

    def create_resource():
        return boto3.resource('dynamodb')

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=side_effect_func)
    def test_get_facebook_user(self, mock_api_call, mock_get_db, body=body):
        self.assertEquals(get_user_by_facebook_id('FACEBOOK_ID'), body)

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=not_found)
    def test_get_facebook_no_id(self, mock_api_call, mock_get_db):
        with self.assertRaises(NotFound):
            get_user_by_facebook_id('FAKE_FACEBOOK_ID')


class TestGetUserByGoogleId(TestCase):
    body = {'google_id': 'GOOGLE_ID', 'name': 'T_GOOGLE', 'id': 'testGetGoogleUser'}

    def side_effect_func(method, arguments):
        if (method == 'Query'):
            return {'Items': [{'google_id': 'GOOGLE_ID', 'name': 'T_GOOGLE', 'id': 'testGetGoogleUser'}]}

    def not_found(method, arguments):
        raise NotFound

    def create_resource():
        return boto3.resource('dynamodb')

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=side_effect_func)
    def test_get_google_user(self, mock_api_call, mock_get_db, body=body):
        self.assertEquals(get_user_by_google_id('GOOGLE_ID'), body)

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=not_found)
    def test_get_google_no_id(self, mock_api_call, mock_get_db):
        with self.assertRaises(NotFound):
            get_user_by_google_id('FAKE_GOOGLE_ID')


class TestUpdateUser(TestCase):
    body_before = {'google_id': 'T_BEFORE', 'email': 'T_BEFORE', 'facebook_id': 'T_BEFORE', 'name': 'T_BEFORE',
                   'id': 'testUpdateUser'}
    body_after = {'google_id': 'T_AFTER', 'email': 'T_AFTER', 'facebook_id': 'T_AFTER', 'name': 'T_AFTER',
                  'id': 'testUpdateUser'}

    def side_effect_func(method, arguments):
        if (method == 'GetItem'):
            return {'Item': {'google_id': 'T_AFTER', 'email': 'T_AFTER', 'facebook_id': 'T_AFTER', 'name': 'T_AFTER',
                'id': 'testUpdateUser'}}

    def not_found(method, arguments):
        raise NotFound

    def create_resource():
        return boto3.resource('dynamodb')

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=side_effect_func)
    def test_update_existent_user(self, mock_api_call, mock_get_db, body_after=body_after):
        update_user('testUpdateUser', body_after)
        self.assertEquals(get_user_by_id('testUpdateUser'), body_after)

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=not_found)
    def test_update_nonexistent_user(self, mock_api_call, mock_get_db, body_after=body_after):
        with self.assertRaises(NotFound):
            update_user('testUpdateNonexistentUser', body_after)


class TestDeleteUser(TestCase):

    def side_effect_func(method, arguments):
        if (method == 'GetItem'):
            if (arguments['Key']['id'] == 'testDeleteNonexistentUser'):
                raise NotFound
            return {'Item': {'google_id': 'T_AFTER', 'email': 'T_AFTER', 'facebook_id': 'T_AFTER', 'name': 'T_AFTER',
                             'id': 'testUpdateUser'}}

    def not_found(function, method, arguments):
        raise NotFound

    def create_resource():
        return boto3.resource('dynamodb')

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=side_effect_func)
    def test_delete_user(self, mock_api_call, mock_get_db):
        delete_user('testDeleteUser')
        with self.assertRaises(NotFound):
            mock_api_call.side_effect = self.not_found
            get_user_by_id('testDeleteUser')

    @patch('app.get_db', side_effect=create_resource)
    @patch('botocore.client.BaseClient._make_api_call', side_effect=side_effect_func)
    def test_delete_nonexistent_user(self, mock_api_call, mock_get_db):
        with self.assertRaises(NotFound):
            delete_user('testDeleteNonexistentUser')
        with self.assertRaises(NotFound):
            get_user_by_id('testDeleteNonexistentUser')