#!/usr/bin/env python3

import unittest
import amulet


class TestDeploy(unittest.TestCase):
    """
    Deployment test for the OpenJDK charm.

    This charm is subordinate and requires a principal that provides the
    'java' relation. Use ubuntu-devenv and ensure java -version works.
    """

    @classmethod
    def setUpClass(cls):
        cls.d = amulet.Deployment(series='trusty')
        cls.d.add('ubuntu-devenv', 'cs:trusty/ubuntu-devenv')
        cls.d.add('openjdk', 'cs:trusty/openjdk')
        cls.d.relate('ubuntu-devenv:java', 'openjdk:java')
        cls.d.setup(timeout=900)
        cls.d.sentry.wait(timeout=1800)
        cls.unit = cls.d.sentry['ubuntu-devenv'][0]

    def test_java(self):
        cmd = "java -version 2>&1 | grep -i 'openjdk.*version'"
        print("running {}".format(cmd))
        output, rc = self.unit.run(cmd)
        print("output from cmd: {}".format(output))
        assert rc == 0, "Unexpected return code: {}".format(rc)

if __name__ == '__main__':
    unittest.main()
