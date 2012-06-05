# -*- coding: utf-8 -*-
import logging

from conf import production_env, mime_type

from webapp2 import RequestHandler, cached_property
from webapp2_extras import jinja2, auth, sessions, jinja2, i18n
from jinja2.runtime import TemplateNotFound

_T = i18n.gettext

class BaseHandler(RequestHandler):
  def dispatch(self):
    # Get a session store for this request.
    # See this for more info on webapp2 sessions:
    # http://webapp-improved.appspot.com/api/webapp2_extras/sessions.html
    self.session_store = sessions.get_store(request=self.request)
    
    i18n.get_i18n().set_locale('en')
    
    try:
      # Dispatch the request.
      RequestHandler.dispatch(self)
    finally:
      # Save all sessions.
      self.session_store.save_sessions(self.response)

  @cached_property
  def session(self):
    """Returns a session using the default cookie key"""
    return self.session_store.get_session()

  @cached_property
  def auth(self):
    """Returns auth data associated with currently logged in user"""
    return auth.get_auth()

  @cached_property
  def user_dict(self):
    """Returns currently logged in user attributes
    See conf/__init__.py for precise list of the attributes stored in the session.
    """
    return self.auth.get_user_by_session()

  @cached_property
  def user(self):
    """Returns currently logged in user model object"""
    return self.auth.store.user_model.get_by_id(self.user_dict['user_id'])

  @cached_property
  def jinja2(self):
    """Returns a Jinja2 renderer cached in the app registry"""
    return jinja2.get_jinja2(app=self.app)
    
  def render(self, template, mime_type=mime_type.HTML, **ctx):
    """Renders template usign Jinja2 and 'plain/html' as default Content-Type"""
    # some default context values
    template_ctx = {
      'production_env': production_env()
    } 
    # merge with passed context
    template_ctx.update(ctx)

    # Set headers
    self.response.headers['Content-Type'] = mime_type

    try:
      # See this on Jinja2 templates:
      # http://jinja.pocoo.org/docs/templates
    
      # render template or respond with 404 Not found
      template_name = '%s.html' % template
      self.response.write(self.jinja2.render_template(template_name, **template_ctx))
    except TemplateNotFound:
      logging.error("Template not found: " + template_name)
      self.error(404)

  def head(self, *args, **kwargs):
    """Some external API might be upset if HEAD requests are not supported
    so we'll simply respond with an empty body and make them happy."""
    pass

class SimpleHandler(BaseHandler):
  def get(self, templ):
    if templ in ['', '/']:
      templ = 'home'
    self.render(templ, msg=_T('It works'))
