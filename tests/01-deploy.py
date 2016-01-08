#!/usr/bin/env python3

import unittest
import amulet


class TestDeploy(unittest.TestCase):
    """
    Deployment test for the OpenJDK charm.
    """

    @classmethod
    def setUpClass(cls):
        cls.d = amulet.Deployment(series='trusty')
        cls.d.add('ubuntu-devenv', 'cs:~kwmonroe/trusty/ubuntu-devenv-1')
        cls.d.add('openjdk', 'cs:~kwmonroe/trusty/openjdk-1')
        cls.d.relate('ubuntu-devenv:java', 'openjdk:java')
        cls.d.setup(timeout=900)
        cls.d.sentry.wait(timeout=1800)
        cls.unit = cls.d.sentry['ubuntu-devenv'][0]

    def test_java(self):
        output, rc = self.unit.run("java -version")
        assert 'OpenJDK' in output, "OpenJDK should be in %s" % output

if __name__ == '__main__':
    unittest.main()
