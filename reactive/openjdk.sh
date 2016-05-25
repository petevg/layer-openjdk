#!/bin/bash
source charms.reactive.sh
set -e

# Update java-related system configuration and relation data. This function
# must only be called from a 'java.connected' state handler.
#
# :param: The major java version (e.g.: 6)
function update_java_data() {
    local java_major=$1
    local java_alternative=$(update-java-alternatives -l | grep java-1.${java_major} | awk {'print $1'})

    # Set our java symlinks to the alternative that matched our major version.
    juju-log "openjdk: updating alternatives with ${java_alternative}"
    update-java-alternatives -s ${java_alternative}

    # Remove any previous mention of JAVA_HOME from /etc/environment.
    sed -i -e '/JAVA_HOME/d' /etc/environment

    # Update environment and relation if we have a /usr/bin/java symlink
    if [[ -L "/usr/bin/java" ]]; then
        local java_home=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
        echo "JAVA_HOME=${java_home}" >> /etc/environment
    fi
}

@when 'java.connected'
@when_not 'java.installed'
function install() {
    local java_type=$(config-get 'java-type')
    local java_major=$(config-get 'java-major')

    if grep -q trusty /etc/lsb-release; then
        # ensure that Java 8 can be installed on trusty
        add-apt-repository -y ppa:openjdk-r/ppa
        apt-get update -qq
    fi

    if [[ `uname -p` == 'ppc64'* ]]; then
        # openjdk-8 needs an arch option on ppc64le
        echo 'JAVA_TOOL_OPTIONS="-Dos.arch=ppc64le"' >> /etc/environment
    fi

    # Install jre or jdk+jre depending on config.
    status-set maintenance "Installing OpenJDK ${java_major} (${java_type})"
    juju-log "openjdk: installing openjdk ${java_major} (${java_type})"
    apt-get update -qq
    if [[ ${java_type} == "jre" ]]; then
      apt-get install -qqy openjdk-${java_major}-jre-headless
    else
      apt-get install -qqy openjdk-${java_major}-jre-headless openjdk-${java_major}-jdk
    fi

    # Register current java information
    update_java_data $java_major
    set_state 'java.installed'
    status-set active "OpenJDK ${java_major} (${java_type}) installed"
    juju-log "openjdk: openjdk ${java_major} (${java_type}) installed"
}

@when 'java.connected' 'java.installed'
function send_info() {
    local java_home=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
    local java_version=$(java -version 2>&1 | grep -i version | head -1 | awk -F '"' {'print $2'})
    relation_call --state=java.connected set_ready $java_home $java_version
}

@when 'java.connected' 'java.installed'
@when 'config.changed.java-major'
function change_major() {
    # Different major java version requested by config, call install().
    # NOTE: no need to check for an java-type change when java-major changes.
    # The install() function will use the current config value whether it
    # changed since initial install or not.
    juju-log "openjdk: java major version change requested"
    install
}

@when 'java.connected' 'java.installed'
@when 'config.changed.java-type'
@when_not 'config.changed.java-major'
function change_type() {
    # Different java-type (but same java-major) requested by config.
    # Update packages accordingly.
    # NOTE: if java-type AND java-major change, that is handled with a
    # reinstall in the above change_major() function.
    local java_type=$(config-get 'java-type')
    local java_major=$(config-get 'java-major')

    if [[ ${java_type} == 'jre' ]]; then
      # Config tells us we only want the JRE. Remove the JDK if it exists.
      if dpkg -s openjdk-${java_major}-jdk &> /dev/null; then
        status-set maintenance "Uninstalling OpenJDK ${java_major} (JDK)"
        juju-log "openjdk: java 'jre' requested; removing jdk if installed"
        apt-get remove --purge -qqy openjdk-${java_major}-jdk
      fi
    else
      # If we're not 'jre', do a full install. Install the JDK unconditionally
      # (it doesn't hurt to install a package that is already installed).
      # NOTE: this will update existing jdk packages to the latest rev of the
      # major release.
      status-set maintenance "Installing OpenJDK ${java_major} (${java_type})"
      juju-log "openjdk: java 'full' requested; installing jdk"
      apt-get install -qqy openjdk-${java_major}-jdk
    fi

    # Register current java information
    update_java_data $java_major
    status-set active "OpenJDK ${java_major} (${java_type}) installed"
    juju-log "openjdk: openjdk ${java_major} (${java_type}) installed"
}

@when 'java.installed'
@when_not 'java.connected'
function uninstall() {
    # Uninstall all versions of OpenJDK
    status-set maintenance "Uninstalling OpenJDK (all versions)"
    juju-log "openjdk: uninstalling openjdk (all versions)"
    apt-get remove --purge -qqy openjdk-[0-9]?-j.*

    remove_state 'java.installed'
    status-set blocked "OpenJDK (all versions) uninstalled"
    juju-log "openjdk: openjdk (all versions) have been uninstalled"
}

reactive_handler_main
