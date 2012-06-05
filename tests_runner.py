"""Run all unittests."""

import os
import sys
import unittest

def load_tests():
  test_mods = [f[:-3] for f in os.listdir('tests') if f.endswith('_test.py')]
  apptests = __import__('tests', fromlist=test_mods, level=1)

  loader = unittest.TestLoader()
  suite = unittest.TestSuite()

  for mod in [getattr(apptests, name) for name in test_mods]:
    for name in set(dir(mod)):
      if name.endswith('Tests'):
        test_module = getattr(mod, name)
        tests = loader.loadTestsFromTestCase(test_module)
        suite.addTests(tests)

  return suite


def main():
  v = 1
  for arg in sys.argv[1:]:
    if arg.startswith('-v'):
      v += arg.count('v')
    elif arg == '-q':
      v = 0
  result = unittest.TextTestRunner(verbosity=v).run(load_tests())
  sys.exit(not result.wasSuccessful())


if __name__ == '__main__':
  main()
