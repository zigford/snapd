# snapd
Gentoo overlay dedicated to provide snapd for installing snap packages in Gentoo.

Keeping in sync with [snapd](https://github.com/snapcore/snapd)

## Requirements

The package has some dependencies and kernel settings that will be required for
installation. The ebuild will complain if they are not set. Of note, is AppArmor
which can be enabled by default in the kernel, or enabled via a kernel command
line parameters.

## Installation

### With Layman

1. Install layman with git use flag

        # echo app-portage/layman git >> /etc/portage/package.use/layman
        # emerge layman

2. Add the snapd overlay

        # layman -L # sync the repo list
        # layman -a snapd

3. Install snapd

        # emerge --ask app-emulation/snapd

### Manually added overlay

```
[snapd]
 
 # An unofficial overlay that supports the installation of the "Snappy"
 backbone.
 # Maintainer: Jesse "zigford" Harris (zigford@gmail.com)
 # Upstream Maintainer: Zygmunt "zyga" Krynicki (me@zygoon.pl)
  
  location = /usr/local/portage/snapd
  sync-type = git
  sync-uri = https://github.com/zigford/snapd.git
  priority = 50
  auto-sync = yes
```

  Then run:

      # emaint sync --repo snapd
      # emerge -a app-emulation/snapd

## Post Installation

Apparmor needs to be enabled and configured as the default security
Ensure /etc/default/grub is updated to include:

        GRUB_CMDLINE_LINIX_DEFAULT="apparmor=1 security=apparmor"

Then update grub, enable snapd, snapd.socket and snapd.apparmor and reboot
