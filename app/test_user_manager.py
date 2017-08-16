from unittest import TestCase

from werkzeug.exceptions import NotFound

from app import create_user, get_user_by_id, get_user_by_facebook_id, get_user_by_google_id, delete_user, \
    get_users_table, update_user


class TestCreateUser(TestCase):
    body = {'google_id': 'GOOGLE_ID', 'email': 'EMAIL', 'facebook_id': 'FACEBOOK_ID', 'name': 'NAME'}

    def test_create_user(self, body=body):
        create_user(body)
        user = get_user_by_id(body['id'])
        body['profile_picture_url'] = 'generic'
        body['profile_pictures_id'] = user['profile_pictures_id']
        body['cover_pictures_id'] = user['cover_pictures_id']
        self.assertEquals(get_user_by_id(body['id']), body)

    def tearDown(self, body=body):
        delete_user(body['id'])


class TestGetUserById(TestCase):
    body = {'google_id': 'GOOGLE_ID', 'email': 'EMAIL', 'facebook_id': 'FACEBOOK_ID', 'name': 'NAME',
            'id': 'testGetUser'}

    def setUp(self, body=body):
        get_users_table().put_item(Item=body)

    def test_get_user(self, body=body):
        self.assertEquals(get_user_by_id('testGetUser'), body)

    def test_get_nonexistent_user(self):
        with self.assertRaises(NotFound):
            get_user_by_id('FAKE_ID')

    def tearDown(self):
        delete_user('testGetUser')


class TestGetUserByFacebookId(TestCase):
    body = {'facebook_id': 'FACEBOOK_ID', 'name': 'T_FACEBOOK', 'id': 'testGetFacebookUser'}

    def setUp(self, body=body):
        get_users_table().put_item(Item=body)

    def test_get_facebook_user(self, body=body):
        self.assertEquals(get_user_by_facebook_id('FACEBOOK_ID'), body)

    def test_get_facebook_no_id(self):
        with self.assertRaises(NotFound):
            get_user_by_facebook_id('FAKE_FACEBOOK_ID')

    def tearDown(self):
        delete_user('testGetFacebookUser')


class TestGetUserByGoogleId(TestCase):
    body = {'google_id': 'GOOGLE_ID', 'name': 'T_GOOGLE', 'id': 'testGetGoogleUser'}

    def setUp(self, body=body):
        get_users_table().put_item(Item=body)

    def test_get_google_user(self, body=body):
        self.assertEquals(get_user_by_google_id('GOOGLE_ID'), body)

    def test_get_google_no_id(self):
        with self.assertRaises(NotFound):
            get_user_by_google_id('FAKE_GOOGLE_ID')

    def tearDown(self):
        delete_user('testGetGoogleUser')


class TestUpdateUser(TestCase):
    body_before = {'google_id': 'T_BEFORE', 'email': 'T_BEFORE', 'facebook_id': 'T_BEFORE', 'name': 'T_BEFORE',
                   'id': 'testUpdateUser'}
    body_after = {'google_id': 'T_AFTER', 'email': 'T_AFTER', 'facebook_id': 'T_AFTER', 'name': 'T_AFTER',
                  'id': 'testUpdateUser'}

    def setUp(self, body_before=body_before):
        get_users_table().put_item(Item=body_before)

    def test_update_existent_user(self, body_after=body_after):
        update_user('testUpdateUser', body_after)
        self.assertEquals(get_user_by_id('testUpdateUser'), body_after)

    def test_update_nonexistent_user(self, body_after=body_after):
        with self.assertRaises(NotFound):
            update_user('testUpdateNonexistentUser', body_after)

    def tearDown(self):
        delete_user('testUpdateUser')


class TestDeleteUser(TestCase):
    def setUp(self):
        get_users_table().put_item(
            Item={'google_id': 'T_DELETE', 'email': 'T_DELETE', 'facebook_id': 'T_DELETE', 'name': 'T_DELETE',
                  'id': 'testDeleteUser'})

    def test_delete_user(self):
        delete_user('testDeleteUser')
        with self.assertRaises(NotFound):
            get_user_by_id('testDeleteUser')

    def test_delete_nonexistent_user(self):
        with self.assertRaises(NotFound):
            delete_user('testDeleteNonexistentUser')
        with self.assertRaises(NotFound):
            get_user_by_id('testDeleteNonexistentUser')
