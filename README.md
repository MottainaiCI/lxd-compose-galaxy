# LXD Compose Galaxy

Ready to go environement files for `lxd-compose`.

In particular, under the directory:

  * **envs**: The tree with all environments for `lxd-compose`


> Note: Keep things always updated and correct needs effort.
>       If you :heart: LXD Compose, help us on testing and to maintain projects.
>       Thanks in advance.

To organize things and share more stable specs, we will organize the tree in
two parts: one directory with `Grade A` (`stable`) containing the project's specs more
stable and another with `Grade B` (`community`) less maintained and validated.


## Getting Started

Show all projects availables.

```
$> lxd-compose p list
```

Show all commands available to run tasks / containers.

```
$> lxd-compose c list
```


## Using Custom LXD Images from Galaxy

Configure your LXD Configuration directory or add the remote with this command:

```shell
$> lxc remote add macaroni https://macaronios.mirror.garr.it/images/lxd-images --protocol simplestreams --public --accept-certificate
```

or for Incus:

```shell
$> incus remote add macaroni https://macaronios.mirror.garr.it/images/lxd-images --protocol simplestreams --public --accept-certificate
```

The lxc config is already available under the `lxd-conf` directory and you can use with `lxc` with this command:
```shell
$> # under lxd-compose-galaxy directory
$> export LXD_CONF=./lxd-conf
$> lxc remote list
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
|      NAME       |                      URL                      |   PROTOCOL    |  AUTH TYPE  | PUBLIC | STATIC | GLOBAL |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| images          | https://images.linuxcontainers.org            | simplestreams | none        | YES    | NO     | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| local (current) | unix://                                       | lxd           | file access | NO     | YES    | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| local-snapd     | unix:///var/snap/lxd/common/lxd/unix.socket   | lxd           | tls         | NO     | NO     | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| macaroni        | https://macaronios.mirror.garr.it/lxd-images  | simplestreams | none        | YES    | NO     | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| ubuntu          | https://cloud-images.ubuntu.com/releases      | simplestreams | none        | YES    | YES    | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| ubuntu-daily    | https://cloud-images.ubuntu.com/daily         | simplestreams | none        | YES    | YES    | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
```

For Incus:
```shell
$> # under lxd-compose-galaxy directory
$> export INCUS_CONF=./lxd-conf
$> incus remote list
...
```
