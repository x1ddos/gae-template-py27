"""Unit tests utilities"""

import os
import sys
import logging
import unittest
import webtest

from google.appengine.ext import testbed

# Add app's lib and ext dirs
sys.path[0:0] = ['lib', 'ext']


class TestBase(unittest.TestCase):
  """Base class for all app tests"""

  APP_ID = '_'

  def setUp(self):
    """Set up test framework. Configures basic environment variables and stubs."""
    self.testbed = testbed.Testbed()
    self.testbed.setup_env(app_id=self.APP_ID)
    self.testbed.activate()
    self.testbed.init_datastore_v3_stub()
    self.testbed.init_memcache_stub()
    self.testbed.init_taskqueue_stub()

    self._logger = logging.getLogger()
    self._old_log_level = self._logger.getEffectiveLevel()

  def tearDown(self):
    """Tear down test framework."""
    self._logger.setLevel(self._old_log_level)
    self.testbed.deactivate()

  def expectErrors(self):
    if self.isDefaultLogging():
      self._logger.setLevel(logging.CRITICAL)

  def expectWarnings(self):
    if self.isDefaultLogging():
      self._logger.setLevel(logging.ERROR)

  def isDefaultLogging(self):
    return self._old_log_level == logging.WARNING

class WebTestBase(TestBase):
  """Base class for web-based tests (handlers).
  In a real test case subclass, do something like this:

  class AppTests(WebTestBase):
    APP = main.app

    def testSomething(self):
      response = self.app.get('/some/url')
      self.assertEqual(response.status_int, 200)

  See http://webtest.pythonpaste.org/en/latest/modules/webtest.html
  """
  def setUp(self):
    super(WebTestBase, self).setUp()
    os.environ['HTTP_HOST'] = 'localhost'

  @property
  def app(self):
    if not getattr(self, '_test_app', None):
      self._test_app = webtest.TestApp(self.APP)
    return self._test_app
