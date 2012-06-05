"""Tests for User model"""

import unittest
from . import test_utils

from models.user import User
from google.appengine.api.datastore_errors import BadValueError

class UserModelTests(test_utils.TestBase):
  def testRequiredProperties(self):
    self.expectWarnings()
    u = User()
    self.assertRaisesRegexp(BadValueError, 'display_name', u.put)


def main():
  unittest.main()


if __name__ == '__main__':
  main()
