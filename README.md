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
$> lxc remote add keybase-geaaru https://geaaru.keybase.pub/lxd-images --protocol simplestreams --public --accept-certificate
```
