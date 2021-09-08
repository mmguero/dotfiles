#!/usr/bin/env bash

# set up booksonic LDAP configuration
pushd ~/services/booksonic >/dev/null 2>&1

for file in /usr/local/share/ca-certificates/*.crt; do docker cp "$file" booksonic:/usr/local/share/ca-certificates/; done

docker-compose exec booksonic bash -c 'for file in /usr/local/share/ca-certificates/*.crt; do keytool -importcert -file "$file" -alias "($(basename "$file" | sed "s/\.crt//")" -keystore /usr/lib/jvm/java-8-openjdk-armhf/jre/lib/security/cacerts -keypass changeit -storepass changeit -noprompt; done; kill $(pidof java)'

popd >/dev/null 2>&1

