"""Tests for lib/fmt.py"""

import unittest
import test_utils

import fmt

class FmtTests(unittest.TestCase):
  def testSimpleFormat(self):
    sf = fmt.simple_format
    self.assertEquals(
      sf('This should not be changed!'), 
         'This should not be changed!')
    self.assertEquals(
      sf('https://example.org'), 
         '<a href="https://example.org" target="_blank" rel="nofollow">example.org</a>')
    self.assertEquals(
      sf('Here\'s some link http://www.cloudware.it in between.'), 
         'Here\'s some link <a href="http://www.cloudware.it" target="_blank" rel="nofollow">www.cloudware.it</a> in between.')



def main():
  unittest.main()


if __name__ == '__main__':
  main()
