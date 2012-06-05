import sys
from os import environ

# inject './lib' dir in the path so that we can simply do "import gdata" 
# or whatever there's in the app lib dir.
sys.path[0:0] = ['lib', 'ext']

from . import secrets
from webapp2 import uri_for
from fmt import simple_format

app_config = {
  'webapp2_extras.sessions': {
    'cookie_name': 'ictdays2012',
    'secret_key': secrets.SESSION_KEY
  },
  'webapp2_extras.i18n': {
    'default_locale': 'en',
    'default_timezone': 'Europe/Rome'
  },
  'webapp2_extras.auth': {
    'user_model'     : 'models.User',
    'user_attributes': ['display_name', 'avatar_url'],
  },
  'webapp2_extras.jinja2': {
    'globals': { 
      'url_for' : uri_for 
    }, 
    'filters': {
      'simple_format': simple_format
    },
    'environment_args': {
      'autoescape': True,
      'extensions': [
          'jinja2.ext.autoescape',
          'jinja2.ext.with_',
          'jinja2.ext.i18n'
      ]
    }
  }
}

def production_env():
  """
  True if running on .appspot.com, False otherwise.
  Appengine uses 'Google App Engine/<version>', Devserver uses 'Development/<version>'.
  
  More about GAE Python app runtime environment:
  http://code.google.com/appengine/docs/python/runtime.html
  """
  return environ.get('SERVER_SOFTWARE', '').startswith('Google')


if production_env():
  app_config['webapp2_extras.jinja2']['environment_args'].update(auto_reload=False)
