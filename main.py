# -*- coding: utf-8 -*-
import sys
from conf import app_config, production_env

from webapp2 import WSGIApplication, Route

# Define URLs to handlers mapping here
routes = [
	Route('/<:.*>', handler='handlers.base.SimpleHandler')
]

app = WSGIApplication(routes, config=app_config, debug=not(production_env()))
# TODO: set 404 and 500 error handlers, e.g.
# app.error_handlers[404] = ...
# app.error_handlers[500] = ...
