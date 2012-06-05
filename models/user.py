# -*- coding: utf-8 -*-
import logging

from google.appengine.ext import ndb
from webapp2_extras.appengine.auth.models import User as Webapp2User

class User(Webapp2User):
  """Subclassed from webapp2's User expando model"""
  display_name = ndb.StringProperty(required=True)
  homepage     = ndb.StringProperty(indexed=False)
  avatar_url   = ndb.StringProperty(default='/img/missing-avatar.jpg', indexed=False)
