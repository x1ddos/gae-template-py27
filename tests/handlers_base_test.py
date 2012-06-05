"""Tests for handlers base"""

import unittest
from . import test_utils

import main

class HandlersBaseTests(test_utils.WebTestBase):
  APP = main.app

  def testHeadResponse(self):
    response = self.app.head('/')
    self.assertEqual(response.status_int, 200)

  def testNotFound(self):
    self.expectErrors()
    response = self.app.get('/random-page', status=404)
    self.assertEqual(response.status_int, 404)

  def testHomepage(self):
    response = self.app.get('/')
    self.assertEqual(response.status_int, 200)



def main():
  unittest.main()


if __name__ == '__main__':
  main()
