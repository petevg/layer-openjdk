# Overview

This is a layered charm that generates a deployable OpenJDK charm. Source for
this charm is available on
[github](https://github.com/juju-solutions/layer-openjdk).


# Usage

This subordinate charm implements the `java` interface and requires a principal
charm that provides the `java` relation endpoint. Example deployment:

    juju deploy cs:~kwmonroe/trusty/ubuntu-devenv
    juju deploy cs:~kwmonroe/trusty/openjdk
    juju add-relation ubuntu-devenv openjdk


# Configuration

### install-type

  This determines which OpenJDK packages to install. Valid options are `jre`
  or `full`. The default is `jre`, which will install the OpenJDK Java Runtime
  Environment (JRE). Setting this to `full` will install the OpenJDK Java
  Development Kit (JDK), which includes the JRE.

  Switch between the JRE and full (JRE+JDK) with the following:

      juju set openjdk install-type=full


### java-major

  Major version of Java to install.  This defaults to `7` and installs
  openjdk-7-[jre|jdk]. Valid options for Ubuntu 14.04 (Trusty) are `6` or `7`.

  Switch between Java7 and Java6 with the following:

      juju set openjdk java-major=6


# Contact Information

- <kevin.monroe@canonical.com>
