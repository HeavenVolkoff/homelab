# Emergency recovery

Instructions to recover from some emergency scenarios when setting up the homelab

## CoreOS fails to execute ignition

> [!WARNING]
>
> DO NOT REBOOT

If this happens you will be dropped in a recovery terminal running bash and with access to some common utilities.
Most notable `env`, `fdisk` and `head` are missing, but we have `bash`, `lsblk`, `curl`, `jq` and `ip`.

First thing is to figure out why the ignition failed so it can be fixed it.
Look into the boot log, the journal: `journalctl -b0` and `cat /run/initramfs/rdsosreport.txt`.
Somewhere in one of these there will be an explanation why ignition failed.
After identifying the problem, fix it and push a new commit to this repo.

Now, back to the recovery terminal, first thing is getting an internet connection up:

- Open a file with vi:

  ```sh
  $> vi ip.sh
  ```

- Enter editable mode: Press `i`.

- Copy the content of script [utilities/ip.sh](../butane/bin/ip.sh) and paste it onto `vi`

- Exit editable mode: Press `[ESC]`

- Save and quit: `:wq`, then press `[ENTER]`

- Make it executable:

  ```sh
  $> chmod +x ip.sh
  ```

- Run the script

If the script fails make sure the machine is physically connected to the Ethernet.

Now, with internet, let's set up a CoreOS live environment:

- Run `lsblk` to make sure we have the `boot` and `efi` partition.
  If you are not sure, and doesn't mind erasing the disk, run these commands:

  ```sh
  $> sgdisk --zap-all /dev/<INSTALL_DISK>
  $> sgdisk \
      --new=1:0:+1M --typecode=1:EF02 --change-name=1:"BIOS boot" \
      --new=2:0:+127M --typecode=2:EF00 --change-name=2:"esp" \
      --new=3:0:0 --typecode=2:ecode=3:8300 --change-name=3:"boot" \
      /dev/<INSTALL_DISK>
  ```

- Mount /boot:

  ```sh
  mount /dev/<BOOT_PARTITION> /boot
  ```

- Repeat the vi instruction above to create the script [coreos-live-setup.sh](../butane/bin/coreos-live-setup.sh)

- Run the script with the URL for the fixed ignition file

- Reboot

