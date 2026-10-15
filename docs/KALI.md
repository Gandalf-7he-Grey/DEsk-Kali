# DEsk on Kali Linux

Kali is a rolling release, and its wlroots is newer than the **0.18** DEsk is
built on: 0.19 and later changed the C API, so DEsk does not compile against
the system's wlroots (the errors are in `wm.c`). `scripts/install_debian.sh`
stops for the same reason -- apt has no `libwlroots-0.18-dev` here.

`scripts/install_kali.sh` does what `install_ubuntu.sh` and `install_arch.sh`
do for their systems: it builds **wlroots 0.18.3 from its own release into
`/opt/desk-wlroots`**, then builds DEsk against it. DEsk's programs carry that
folder as their run path, so DEsk finds that wlroots and **nothing else on the
system does** -- Sway, Hyprland or anything else linked against the system's
wlroots is not touched.

## Install

```sh
git clone https://github.com/Gandalf-7he-Grey/DEsk-Kali.git
cd DEsk-Kali
sh scripts/install_kali.sh        # asks before installing packages; --yes does not
```

(`sh scripts/install_session.sh` finds this script by itself on Kali.)

It:

1. installs, with apt, what DEsk and wlroots are built from, plus the fonts and
   tools DEsk uses (`--no-packages` skips this);
2. fetches wlroots 0.18.3, checks its SHA-256, builds it and installs it in
   `/opt/desk-wlroots` -- kept, not built again, when it is there already;
3. builds DEsk in `build-kali` and installs it in `/usr/local`, through
   `scripts/install.sh`, which also puts "DEsk" on the login screen;
4. checks that the `desk` program finds that wlroots.

Try it as a window in your current session first:

```sh
desk -s xfce4-terminal
```

Then log out and pick "DEsk" from the session menu on the login screen.

The programs DEsk is meant to be used with (file manager, text editor, ...)
are installed by `sh scripts/install-desktop.sh`; `desk-settings --check` says
what each row of Shell Settings would open and which package would bring it.

Options: `--prefix DIR` (where DEsk goes), `--wlroots-prefix DIR`, `--plan`
(say what it would do and stop), `--help`.

## Update

Get the new copy and run `sh scripts/install_kali.sh` again. wlroots is kept;
DEsk is built afresh in `build-kali` (about half a minute).

## Remove

```sh
sudo ninja -C build-kali uninstall      # DEsk itself (from the build it came from)
sudo rm -rf /opt/desk-wlroots           # its wlroots
sudo rm -f /usr/share/wayland-sessions/desk.desktop /etc/pam.d/desk
```

## When something goes wrong

- `~/.local/state/desk/session.log` is what DEsk said as it ran;
  `~/.local/state/desk/install.log` is what the installer said.
- apt names a package it cannot find: Kali's package names move now and then.
  Send the name; it is the `build_pkgs` list at the top of
  `scripts/install_kali.sh` to change.
- `ldd /usr/local/bin/desk | grep wlroots` should point into
  `/opt/desk-wlroots/lib`. If it points anywhere else, DEsk was linked against
  the system's wlroots, and `sh scripts/install_kali.sh` again (it builds afresh)
  is the way to put it right.

## Status

Built and started as a window on Kali rolling (wlroots 0.18.3 beside the
system's 0.20, gcc 16, Meson 1.12) by a user, not by DEsk's author; the
installer script was written from that build and has been run through its build
and install steps, but a full run of it on a clean Kali has not been seen by
whoever wrote it. Reports are welcome.
