#!/usr/bin/env python3

import connexion

if __name__ == '__main__':
    app = connexion.App(__name__, 8080,
    specification_dir='./swagger/')
    app.add_api('swagger.yaml', arguments={'title': 'NGRA User Management API'})
    app.run()
