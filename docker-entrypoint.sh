#!/bin/sh

set -e

# reset previously modified urlhelper.php, in case ALLOW_PORTS is updated
git checkout -- /var/www/classes/urlhelper.php

if [ "$ALLOW_PORTS" != "80,443" ]; then
    # open ports in the env
    ALLOW_PORTS="80, 443, $ALLOW_PORTS, ''"
    sed -i -r "s/(80, 443).*?('')/$ALLOW_PORTS/" /var/www/classes/urlhelper.php

    # modify BL to include ports
    CODE="if (isset(\$parts['port'])) \$tmp .= ':' . \$parts['port']; \n"
    sed -i "/if (isset(\$parts\['path'\]))/i $CODE" /var/www/classes/urlhelper.php
fi

if [ "$FEED_LOG_QUIET" != "true" ]; then
    sed -i -r "s/--quiet/ /" /etc/s6/update-daemon/run
else
    sed -i -r "s/\.php/.php --quiet/" /etc/s6/update-daemon/run
fi

if [ -n "$DB_USER_FILE" ]; then DB_USER="$(cat $DB_USER_FILE)"; fi

if [ -n "$DB_PASS_FILE" ]; then DB_PASS="$(cat $DB_PASS_FILE)"; fi

if [[ -z ${PUID} && -z ${PGID} ]] || [[ ${PUID} = 65534 && ${PGID} = 65534 ]] || [[ ${PUID} = 0 && ${PGID} = 0 ]]; then
	echo -e "\033[31mIgnore permission settings. Start with 1000:1000 user\033[0m"
	export PUID=1000
    export PGID=1000
	groupmod -o -g "$PGID" ttrss
	usermod -o -u "$PUID" ttrss
else
	groupmod -o -g "$PGID" ttrss
	usermod -o -u "$PUID" ttrss
fi

mkdir -p /root/.config/git
chown -R ttrss:ttrss /root/.gitconfig /root/.config/git /var/www

sh /wait-for.sh $DB_HOST:$DB_PORT -- php /initialize.php && \
sudo -E -u ttrss php /var/www/update.php --update-schema=force-yes && \
chown -R ttrss:ttrss /root/.gitconfig /root/.config/git /var/www && \
exec s6-svscan /etc/s6/

exec "$@"
