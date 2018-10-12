#!/bin/bash

export_vars=$(cgroup-limits); export $export_vars
export DOCUMENTROOT=${DOCUMENTROOT:-/}

# Default php.ini configuration values, all taken 
# from php defaults.
export ERROR_REPORTING=${ERROR_REPORTING:-E_ALL & ~E_NOTICE}
export DISPLAY_ERRORS=${DISPLAY_ERRORS:-ON}
export DISPLAY_STARTUP_ERRORS=${DISPLAY_STARTUP_ERRORS:-OFF}
export TRACK_ERRORS=${TRACK_ERRORS:-OFF}
export HTML_ERRORS=${HTML_ERRORS:-ON}
export INCLUDE_PATH=${INCLUDE_PATH:-.:/opt/app-root/src:/usr/share/pear}
export SESSION_PATH=${SESSION_PATH:-/tmp/sessions}
export SHORT_OPEN_TAG=${SHORT_OPEN_TAG:-OFF}
# TODO should be dynamically calculated based on container memory limit/16
export OPCACHE_MEMORY_CONSUMPTION=${OPCACHE_MEMORY_CONSUMPTION:-16M}
export OPCACHE_REVALIDATE_FREQ=${OPCACHE_REVALIDATE_FREQ:-2}
export PCRE_ENABLE_JIT=${PCRE_ENABLE_JIT:-0} # http://php.net/manual/en/pcre.configuration.php#ini.pcre.jit
export ZEND_ASSERTIONS=${ZEND_ASSERTIONS:--1} # http://php.net/zend.assertions
export ASSERT_ACTIVE=${ASSERT_ACTIVE:-On} # http://php.net/assert.exception

export PHPRC=${PHPRC:-/etc/php.ini}
export PHP_INI_SCAN_DIR=${PHP_INI_SCAN_DIR:-/etc/php.d}

export HTTPD_START_SERVERS=${HTTPD_START_SERVERS:-8}
export HTTPD_MAX_SPARE_SERVERS=$((HTTPD_START_SERVERS+10))

if [ -n "${NO_MEMORY_LIMIT:-}" -o -z "${MEMORY_LIMIT_IN_BYTES:-}" ]; then
  #
  export HTTPD_MAX_REQUEST_WORKERS=${HTTPD_MAX_REQUEST_WORKERS:-256}
else
  # A simple calculation for MaxRequestWorkers would be: Total Memory / Size Per Apache process.
  # The total memory is determined from the Cgroups and the average size for the
  # Apache process is estimated to 15MB.
  max_clients_computed=$((MEMORY_LIMIT_IN_BYTES/1024/1024/15))
  # The MaxClients should never be lower than StartServers, which is set to 5.
  # In case the container has memory limit set to <64M we pin the MaxClients to 4.
  [[ $max_clients_computed -le 4 ]] && max_clients_computed=4
  export HTTPD_MAX_REQUEST_WORKERS=${HTTPD_MAX_REQUEST_WORKERS:-$max_clients_computed}
  echo "-> Cgroups memory limit is set, using HTTPD_MAX_REQUEST_WORKERS=${HTTPD_MAX_REQUEST_WORKERS}"
fi

envsubst < /opt/app-root/etc/php.ini.template > $PHPRC

for template in /opt/app-root/etc/php.d/*.template; do
    envsubst < ${template} > $PHP_INI_SCAN_DIR/$(basename ${template} .template)
done
for template in /opt/app-root/etc/conf.d/*.template; do
    envsubst < ${template} > /opt/app-root/etc/conf.d/$(basename ${template} .template)
done

exec httpd -D FOREGROUND
