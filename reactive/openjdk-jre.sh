#!/bin/bash

set -ex

source $CHARM_DIR/bin/charms.reactive.sh

# Remove any previous mention of JAVA_HOME, then append the appropriate value
# based on the source of our /usr/bin/java symlink (if it exists).
function update_java_home() {
    sed -i -e '/JAVA_HOME/d' /etc/environment

    if [[ -L "/usr/bin/java" ]]; then
        java_home=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
        echo "JAVA_HOME=${java_home}" >> /etc/environment
    fi
}

@when 'jre.connected'
@when_not 'jre.installed'
function install() {
    java_major=$(config-get 'java-major')
    status-set maintenance "Installing OpenJDK JRE $java_major"
    apt-get update -q
    apt-get install -qqy openjdk-${java_major}-jre-headless
    update_java_home

    # Send relation data
    java_home=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
    java_version=$(java -version 2>&1 | head -1 | awk -F '"' {'print $2'})
    relation_call --relation_name=jre set_ready $java_home $java_version

    set_state 'jre.installed'
    status-set active "OpenJDK JRE $java_major installed"
}

@when 'jre.connected' 'jre.installed'
function check_version() {
    java_major=$(config-get 'java-major')
    java_major_installed=$(java -version 2>&1 | head -1 | awk -F '.' {'print $2'})

    # Install new major version if the user has set 'java-major' to something
    # different than the version we have installed.
    if [[ $java_major != $java_major_installed ]]; then
        status-set maintenance "Installing OpenJDK JRE $java_major"
        apt-get update -q
        apt-get install -qqy openjdk-${java_major}-jre-headless

        # switch all java-related symlinks to the version we just installed,
        # and update our environment with the new JAVA_HOME.
        java_alternative=$(update-java-alternatives -l | grep java-1.${java_major} | awk {'print $1'})
        update-java-alternatives -s ${java_alternative}
        update_java_home

        status-set active "OpenJDK JRE $java_major installed"
    fi
}

@when 'jre.installed'
@when_not 'jre.connected'
function uninstall() {
    status-set maintenance "Uninstalling OpenJDK JRE"
    apt-get remove --purge -qqy "openjdk-[0-9]?-jre-headless"
    update_java_home

    # TODO: need to find a way to unset when jre relation is gone
    #relation_call --relation_name=jre unset_ready
    status-set blocked "OpenJDK JRE uninstalled"
}

reactive_handler_main
