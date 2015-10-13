> Back to [Table of Contents](https://github.com/jpfluger/examples)

# LVM

[Logical Volume Managment](https://en.wikipedia.org/wiki/Logical_Volume_Manager_(Linux)) (aka LVM) commands.

## Create

Create the physical volume.

```bash
$ sudo pvcreate /dev/sdb
```

Create the volume group from one or more physical volumes.

```bash
$ sudo vgcreate mydrive /dev/sdb
```

Create one or more logical volumes on the volume group.

```bash
# limit the size
$ sudo lvcreate --name myfiles --size 100G mydrive
# all free space
$ sudo lvcreate --name mymovies --extents 100%FREE mydrive
```

Format the logical volume with your file system of choice.

```bash
$ sudo mkfs.ext4 /dev/mydrive/myfiles
```

Mount it. You may need to create a directory on which to mount the logical volume.

```bash
# mount point directory
$ sudo mkdir /myfiles
# mount the LV group by mapping the LV to the mount point
$ sudo mount  /dev/mydrive/myfiles /myfiles
```

## Auto-mount LV Group

On device startup, instruct Ubuntu to auto-mount the logical volume. The `mount` command (run above) is temporary for the current session and will disappear on reboot.

Find the block id.

```bash
$ sudo blkid
```

Open `fstab`.

```bash
$ sudo vim /etc/fstab
```

Insert an entry at the bottom of the file.

```
UUID=XXXXXXXXXXXXXXXX /myfiles   ext4   defaults   0   2
```