# Keystone Docker

[![](https://images.microbadger.com/badges/version/stephenhsu/keystone.svg)](https://hub.docker.com/r/stephenhsu/keystone/ "Get your own version badge on microbadger.com")
[![](https://images.microbadger.com/badges/image/stephenhsu/keystone.svg)](https://hub.docker.com/r/stephenhsu/keystone/)
[![Docker Hub](http://img.shields.io/docker/pulls/stephenhsu/keystone.svg)](https://hub.docker.com/r/stephenhsu/keystone/)

This repo is used to host a bunldle to create a docker container (based on
`Python 2.7.12`) running Keystone.

Keystone is an OpenStack service that provides API client authentication,
service discovery, and distributed multi-tenant authorization by implementing
[OpenStack’s Identity API](http://specs.openstack.org/openstack/keystone-specs/).


# What can this docker image do ?

* Running Keystone with **http** (default) or
    **https** (by passing `-e TLS_ENABLED=true`,
    see more in [Environment Variables Explanations](https://github.com/dixudx/keystone-docker#environment-variables-explanations)) enabled;
* Uses the **Apache Web Server** with `mod_wsgi` to serve Identity service
    requests on port `5000` and `35357`;
* Supports remote mysql database;
* Utilizes **Memcached** to store tokens, reducing the burden of MySQL database;
* Customizes/Builds your own Keystone docker image by editing the value
    of `KEYSTONE_VERSION` in `Dockerfile`;


# How to get the image ?

* just pull it from Dockerhub

    ```sh
    $ docker pull stephenhsu/keystone
    ```

* Build your own Keystone version using Dockerfile

    You can find more [Keystone release version](https://github.com/openstack/keystone/releases#).

    ```sh
    $ git clone https://github.com/dixudx/keystone-docker
    $ cd keystone-docker
    $ # edit the value of KEYSTONE_VERSION to your favorite Keystone
    $ # release version
    $ vim Dockerfile
    $ docker build -t keystone:your_version ./
    ```

    **WARNING: Pay attention to the dependencies. You may need to specify
    dependency versions explicitly.**

# How to run the container

## Quick Start

Just run

```
$ docker run -d -p 5000:5000 -p 35357:35357 --name my_keystone stephenhsu/keystone
```

Now you can access <http://localhost:5000> and  <http://localhost:35357>.

## Login into Keystone container

After the container is up,

```sh
$ docker exec -it my_keystone bash
$ # Inside the container
root@26bd2b8a8a60 /root # source openrc
root@26bd2b8a8a60 /root # openstack user list
+----------------------------------+-------+
| ID                               | Name  |
+----------------------------------+-------+
| 609170cf45f64de68c4815c1f6e337b2 | admin |
+----------------------------------+-------+
```

**Note**: *You can also copy the `/root/openrc` to your other servers. After replacing
`OS_AUTH_URL` to the corresponding url, you can access the keystone service
from other servers after sourcing it.*

## Environment Variables Explanations

| Environment Variables              | Default Value | Editable when starting a container                      | Description                                                                                      |
|------------------------------------|---------------|---------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| KEYSTONE_VERSION                   | 9.1.0         | False. Built in Dockerfile unless rebuilding the image. | The release version of Keystone.You can find more at https://github.com/openstack/keystone/tags. |
| KEYSTONE_ADMIN_PASSWORD            | passw0rd      | True                                                    | The Keystone admin user password;                                                                |
| KEYSTONE_DB_ROOT_PASSWD            | passw0rd      | False. Built in Dockerfile unless rebuilding the image. | Keystone MySQL (default localhost) database root user password;                                  |
| KEYSTONE_DB_PASSWD                 | passw0rd      | True                                                    | Keystone MySQL (default localhost) database keystone user password;                              |
| TLS_ENABLED                        | false         | True                                                    | Whether to enable tls/https;                                                                     |
| KEYSTONE_DB_HOST                   |               | True                                                    | MySQL remote database host; Combined with KEYSTONE_DB_ROOT_PASSWD_IF_REMOTED                     |
| KEYSTONE_DB_ROOT_PASSWD_IF_REMOTED |               | True                                                    | MySQL remote database root user password; Combined with KEYSTONE_DB_HOST                         |

## CSR (Certificate Signing Request) Environment Variables

If you've enabled `TLS_ENABLED` (with `-e TLS_ENABLED=true`), below environment
variables have to be noticed. You can just ignore them if you
don't want to make any further customizations.

| Environment Name | Default Value | Meaning             | Example         |
|------------------|---------------|---------------------|-----------------|
| CONUTRY          | NULL          | Country             | GB              |
| STATE            | NULL          | State               | London          |
| LOCALITY         | NULL          | Location            | London          |
| ORG              | NULL          | Organization        | Global Security |
| ORG_UNIT         | NULL          | Organizational Unit | IT Department   |
| CN               | The Hostname  | Common Name         | example.com     |

**Note**: *Be aware of `CN` (the default value is `$hostname`). You'd better
not change it to other value.*


## Example 1: Running with TLS enabled

```sh
$ docker run -d -p 5000:5000 -p 35357:35357 -e TLS_ENABLED=true \
    -h mykeystone.com --name my_keystone_tls stephenhsu/keystone
```

## Example 2: Running with remote MySQL database

```sh
$ docker run -d -p 5000:5000 -p 35357:35357 -e KEYSTONE_DB_HOST=192.168.100.202 \
    -e KEYSTONE_DB_ROOT_PASSWD_IF_REMOTED=your_password \
    -h mykeystone.com --name my_keystone_db stephenhsu/keystone
```

## Example 3: Accessing the Apache Certificate File

```sh
$ mkdir -p ./apache/
$ docker run -d -p 5000:5000 -p 35357:35357 -v `pwd`/apache/:/etc/apache2 \
    -h mykeystone.com --name my_keystone_ca stephenhsu/keystone
```

## Example 4: Customize your Keystone configuration

```sh
$ git clone https://github.com/dixudx/keystone-docker.git
$ cd keystone-docker
# then modify all related configurations in folder ./etc
# especially ./etc/keystone.conf
$ docker run -d -p 5000:5000 -p 35357:35357 -v `pwd`/etc/:/etc/keystone/ \
    -h mykeystone.com --name my_keystone_ca stephenhsu/keystone
```

You can copy `/root/openrc` in your container to your host server,
and replace `OS_CACERT` to this `$pwd/apache/ssl/apache.crt`
(replace `$pwd` with your real directory path).
So that you access the keystone services using openstack python client
( `pip install python-openstackclient` ) from outer of the the container.

**Note**: *On your host server,
you may also need to add `mykeystone.com` to `/etc/hosts`.*


# Reference

* [Keystone, the OpenStack Identity Service](http://docs.openstack.org/developer/keystone/)
* [Installing Keystone](http://docs.openstack.org/developer/keystone/installing.html)
