# LXD Compose Galaxy

Ready to go environement files for `lxd-compose`.

In particular, under the directory:

  * **simplestreams**: The tree and sources file
    for [simplestreams-builder](https://github.com/MottainaiCI/simplestreams-builder) project.

  * **envs**: The tree with all environments for `lxd-compose`

> Note: Currently, this repository is a ready to go lxd-compose tree but will be soon
>       integrated witih the lxd-compose galaxy integration.

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
$> lxc remote add macaroni https://images.macaronios.org/lxd-images --protocol simplestreams --public --accept-certificate
```

The lxc config is already available under the `lxd-conf` directory and you can use with `lxc` with this command:
```shell
$> # under lxd-compose-galaxy directory
$> export LXD_CONF=./lxd-conf
$> lxc remote list
$ lxc remote list
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
|      NAME       |                      URL                      |   PROTOCOL    |  AUTH TYPE  | PUBLIC | STATIC | GLOBAL |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| images          | https://images.linuxcontainers.org            | simplestreams | none        | YES    | NO     | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| local (current) | unix://                                       | lxd           | file access | NO     | YES    | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| local-snapd     | unix:///var/snap/lxd/common/lxd/unix.socket   | lxd           | tls         | NO     | NO     | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| macaroni        | https://images.macaronios.org/lxd-images      | simplestreams | none        | YES    | NO     | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| ubuntu          | https://cloud-images.ubuntu.com/releases      | simplestreams | none        | YES    | YES    | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
| ubuntu-daily    | https://cloud-images.ubuntu.com/daily         | simplestreams | none        | YES    | YES    | NO     |
+-----------------+-----------------------------------------------+---------------+-------------+--------+--------+--------+
```

NOTE: Exporting LXD_CONF on lxc command supplied by snapd doesn't work correctly. In this case just copy the config.yml under the
      snapd comman directory.

