#!/usr/bin/env bash

TLS_ENABLED=${TLS_ENABLED:-false}
if $TLS_ENABLED; then
    HTTP="https"
    CN=${CN:-$HOSTNAME}
    # generate pem and crt files
    mkdir -p /etc/apache2/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/apache2/ssl/apache.key -out /etc/apache2/ssl/apache.crt \
        -subj "/C=$CONUTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$CN"
else
    HTTP="http"
fi

if [ -z $KEYSTONE_DB_HOST ]; then
    KEYSTONE_DB_HOST=localhost
    # start mysql locally
    service mysql restart

    #Docker OverlayFS compatibility: implements subset POSIX standards
    #https://docs.docker.com/storage/storagedriver/overlayfs-driver/
    #ALT: attach /var/lib/mysql as a volume to avoid timeout
    if [ $? ] ; then
        find /var/lib/mysql -type f -exec touch {} \;
        service mysql restart
    fi
else
    if [ -z $KEYSTONE_DB_ROOT_PASSWD_IF_REMOTED ]; then
        echo "Your'are using Remote MySQL Database; "
        echo "Please set KEYSTONE_DB_ROOT_PASSWD_IF_REMOTED when running a container."
        exit 1;
    else
        KEYSTONE_DB_ROOT_PASSWD=$KEYSTONE_DB_ROOT_PASSWD_IF_REMOTED
    fi
fi

addgroup --system keystone >/dev/null || true
adduser --quiet --system --home /var/lib/keystone \
        --no-create-home --ingroup keystone --shell /bin/false \
        keystone || true

if [ "$(id -gn keystone)"  = "nogroup" ]
then
    usermod -g keystone keystone
fi

# create appropriate directories
mkdir -p /var/lib/keystone/ /etc/keystone/ /var/log/keystone/

# change the permissions on key directories
chown keystone:keystone -R /var/lib/keystone/ /etc/keystone/ /var/log/keystone/
chmod 0700 /var/lib/keystone/ /var/log/keystone/ /etc/keystone/

# Keystone Database and user
sed -i 's|KEYSTONE_DB_PASSWD|'"$KEYSTONE_DB_PASSWD"'|g' /keystone.sql
mysql -uroot -p$KEYSTONE_DB_ROOT_PASSWD -h $KEYSTONE_DB_HOST < /keystone.sql

# Update keystone.conf
sed -i "s/KEYSTONE_DB_PASSWORD/$KEYSTONE_DB_PASSWD/g" /etc/keystone/keystone.conf
sed -i "s/KEYSTONE_DB_HOST/$KEYSTONE_DB_HOST/g" /etc/keystone/keystone.conf

# Start memcached
/usr/bin/memcached -u root & >/dev/null || true

# Populate keystone database
su -s /bin/sh -c 'keystone-manage db_sync' keystone

# Bootstrap keystone
keystone-manage bootstrap --bootstrap-username admin \
		--bootstrap-password $KEYSTONE_ADMIN_PASSWORD \
		--bootstrap-project-name admin \
		--bootstrap-role-name admin \
		--bootstrap-service-name keystone \
		--bootstrap-admin-url "$HTTP://$HOSTNAME:35357/v3" \
		--bootstrap-public-url "$HTTP://$HOSTNAME:5000/v3" \
		--bootstrap-internal-url "$HTTP://$HOSTNAME:5000/v3"

# Write openrc to disk
cat > /root/openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${KEYSTONE_ADMIN_PASSWORD}
export OS_AUTH_URL=$HTTP://${HOSTNAME}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

# Configure Apache2
echo "ServerName $HOSTNAME" >> /etc/apache2/apache2.conf

# if TLS is enabled
if $TLS_ENABLED; then
echo "export OS_CACERT=/etc/apache2/ssl/apache.crt" >> /root/openrc
a2enmod ssl
sed -i '/<VirtualHost/a \
    SSLEngine on \
    SSLCertificateFile /etc/apache2/ssl/apache.crt \
    SSLCertificateKeyFile /etc/apache2/ssl/apache.key \
    ' /etc/apache2/sites-available/keystone.conf
fi

# ensite keystone and start apache2
a2ensite keystone
apache2ctl -D FOREGROUND
