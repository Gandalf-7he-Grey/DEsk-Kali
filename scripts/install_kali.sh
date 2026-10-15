#!/bin/sh
# install_kali.sh -- DEsk on Kali Linux, in one go.
#
# Kali is a rolling release: its wlroots is newer (0.20 at the time of
# writing) than the 0.18 DEsk is built on, and 0.19 and later changed the C
# API, so DEsk does not compile against the system's. This builds wlroots
# 0.18.3 from its own release into /opt/desk-wlroots, where only DEsk looks
# for it (its programs carry that folder as their run path; nothing else on
# the system is told of it), then builds and installs DEsk against it with
# scripts/install.sh, which also puts DEsk on the login screen. It is what
# scripts/install_ubuntu.sh and install_arch.sh do for their systems, and
# the same wlroots release.
#
#   --yes                  do not ask before installing packages
#   --no-packages          do not touch apt: the packages are there already
#   --prefix DIR           where DEsk goes (default /usr/local)
#   --wlroots-prefix DIR   where wlroots 0.18 goes (default /opt/desk-wlroots)
#   --plan                 say what it would install and build, and stop
#   --help                 this
#
# Run it as yourself from the folder you got DEsk in; it asks for sudo when
# it needs to. It installs what DEsk is built from, not the programs that
# go with it (a terminal, file manager, text editor, ...): that is what
# scripts/install-desktop.sh is for, and Kali's own are used until then.
# When it is done,
# log out and pick "DEsk" on the login screen, or try it first as a window
# from a terminal in your current session:  desk -s xfce4-terminal
#
# To update, get the new copy and run it again: wlroots is kept if it is
# there already, and DEsk is built afresh in build-kali (about half a
# minute), so that it carries the run path whatever the folder held before.
set -eu

prefix="${PREFIX:-/usr/local}"
wlr="${DESK_WLROOTS_PREFIX:-/opt/desk-wlroots}"
yes=no
plan=no
packages=yes
while [ $# -gt 0 ]; do
	case "$1" in
	--yes|-y) yes=yes ;;
	--plan) plan=yes ;;
	--no-packages) packages=no ;;
	# (what install_session.sh hands on: this installs no programs either way)
	--no-apps|--bare) ;;
	--prefix)
		[ $# -ge 2 ] || { echo "install_kali.sh: --prefix wants a folder" >&2; exit 2; }
		prefix=$2
		shift
		;;
	--prefix=*) prefix=${1#--prefix=} ;;
	--wlroots-prefix)
		[ $# -ge 2 ] || { echo "install_kali.sh: --wlroots-prefix wants a folder" >&2; exit 2; }
		wlr=$2
		shift
		;;
	--wlroots-prefix=*) wlr=${1#--wlroots-prefix=} ;;
	-h|--help) sed -n '2,/^set /s/^# \{0,1\}//p' "$0"; exit 0 ;;
	*) echo "install_kali.sh: what is $1? (--help says what it takes)" >&2; exit 2 ;;
	esac
	shift
done
case "$prefix" in
/?*) prefix=${prefix%/} ;;
*) echo "install_kali.sh: the prefix has to be a whole path, like /usr/local" >&2; exit 2 ;;
esac
case "$wlr" in
/?*) wlr=${wlr%/} ;;
*) echo "install_kali.sh: the wlroots prefix has to be a whole path, like /opt/desk-wlroots" >&2; exit 2 ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/build-kali"

say() { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
die() { printf 'install_kali.sh: %s\n' "$*" >&2; exit 1; }

# The wlroots it builds: the release, where it comes from and its SHA-256
# (the same as in install_ubuntu.sh and install_arch.sh), and how it is set up.
wlrver=0.18.3
wlrurl="https://gitlab.freedesktop.org/wlroots/wlroots/-/releases/$wlrver/downloads/wlroots-$wlrver.tar.gz"
wlrsum=164a7c8bf9f8ae2c1fb00e7bddb6f08cad7e81b3eb35577b48483b1ac265a087
wlropts="-Dexamples=false -Dwerror=false -Dbackends=drm,libinput,x11 -Drenderers=gles2 \
-Dallocators=gbm -Dsession=enabled -Dxwayland=enabled -Dlibliftoff=disabled \
-Dcolor-management=disabled -Dxcb-errors=disabled -Dicon_directory=/usr/share/icons"

# What DEsk and that wlroots are built from (Debian package names, as Kali
# has them), and what DEsk uses while it runs.
build_pkgs="build-essential meson ninja-build pkg-config curl ca-certificates \
libwayland-dev wayland-protocols libxkbcommon-dev libcairo2-dev libpixman-1-dev \
libfontconfig-dev libdrm-dev libpam0g-dev libsystemd-dev libpulse-dev libinput-dev \
libegl-dev libgles-dev libgbm-dev libseat-dev libudev-dev libdisplay-info-dev hwdata \
xwayland libxcb-ewmh-dev libxcb-composite0-dev libxcb-res0-dev libxcb-xfixes0-dev \
libxcb-render0-dev libxcb-render-util0-dev libxcb-dri3-dev libxcb-present-dev \
libxcb-shm0-dev libxcb-xinput-dev libxcb-icccm4-dev libxcb-errors-dev libwayland-bin"
run_pkgs="fonts-urw-base35 fonts-noto-cjk grim wl-clipboard xdg-utils"
# nice to have, and not a reason to stop if apt has no such package
extra_pkgs="fonts-klee"

if ! grep -q "^project('desk'" "$root/meson.build" 2>/dev/null; then
	die "$root does not look like DEsk's source folder (no meson.build for it)"
fi

# -- which system ------------------------------------------------------------
# (DESK_KALI_FORCE=1: run it anyway, on another Debian-based system whose
# wlroots is not 0.18)
name="this system"
if [ -r /etc/os-release ]; then
	# shellcheck disable=SC1091
	name=$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-${ID:-this system}}")
	# shellcheck disable=SC1091
	like=$(. /etc/os-release && printf '%s %s' "${ID:-}" "${ID_LIKE:-}")
else
	like=""
fi
case " $like " in
*" kali "*) ;;
*)
	if [ -z "${DESK_KALI_FORCE:-}" ]; then
		die "this is $name, not Kali. For Debian 13, Ubuntu and Arch use
scripts/install_session.sh. (DESK_KALI_FORCE=1 runs this anyway on a Debian-based system
whose wlroots is not 0.18.)"
	fi
	;;
esac
command -v apt-get >/dev/null 2>&1 || die "there is no apt-get here"

say "DEsk on $name"
say
say "  source          $root"
say "  DEsk goes to    $prefix"
say "  wlroots $wlrver   $wlr (for DEsk only)"
say "  build           $build"

if [ "$plan" = yes ]; then
	say
	say "It would install, with apt:"
	say "  $build_pkgs"
	say "  $run_pkgs"
	say "  (and, if apt has it: $extra_pkgs)"
	say "build wlroots $wlrver from"
	say "  $wlrurl"
	say "into $wlr, then build DEsk in $build and install it in $prefix"
	say "with scripts/install.sh, and put \"DEsk\" on the login screen."
	exit 0
fi

# -- root's work through sudo, the build as ourselves ----------------------------
if [ "$(id -u)" -eq 0 ]; then
	as_root() { "$@"; }
else
	command -v sudo >/dev/null 2>&1 \
		|| die "installing needs root: run this as root, or install sudo and add yourself to it"
	as_root() { sudo "$@"; }
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# -- 1. packages ------------------------------------------------------------
if [ "$packages" = yes ]; then
step "Packages"
say "From apt: what DEsk and wlroots $wlrver are built from, and the fonts and"
say "tools DEsk uses. Nothing is removed, and what is installed already is left as it is."
if [ "$yes" != yes ]; then
	printf 'Install them now? [Y/n] '
	read -r answer || answer=n
	case "$answer" in
	""|y|Y|yes|YES) ;;
	*) die "stopped, as asked. (--yes does not ask; --plan lists what it would do)" ;;
	esac
fi
as_root apt-get update || say "Note: apt-get update had trouble (above); going on with the lists it has."
# shellcheck disable=SC2086
as_root apt-get install -y $build_pkgs $run_pkgs \
	|| die "apt could not install the packages above. What it names as missing is the thing to
look at (a package that is called something else on this Kali); then run this again."
for p in $extra_pkgs; do
	as_root apt-get install -y "$p" >/dev/null 2>&1 || say "  (no $p from apt: skipped)"
done
fi

# -- 2. wlroots 0.18 --------------------------------------------------------
step "wlroots $wlrver, built into $wlr"
pcpath="$wlr/lib/pkgconfig:$wlr/share/pkgconfig"
have_wlroots() {
	PKG_CONFIG_PATH=$pcpath pkg-config --exact-version="$wlrver" wlroots-0.18 2>/dev/null \
		&& [ "$(PKG_CONFIG_PATH=$pcpath pkg-config --variable=have_xwayland wlroots-0.18 2>/dev/null)" = true ]
}
if have_wlroots; then
	say "  wlroots $wlrver, with Xwayland, is in $wlr already: kept."
else
	f="$tmp/wlroots-$wlrver.tar.gz"
	say "  fetching wlroots-$wlrver.tar.gz"
	curl -fsSL --retry 3 -o "$f" "$wlrurl" || die "could not fetch $wlrurl"
	printf '%s  %s\n' "$wlrsum" "$f" | sha256sum -c --status \
		|| die "wlroots-$wlrver.tar.gz is not the file it should be (its SHA-256 differs); try again later"
	tar -xf "$f" -C "$tmp"
	src="$tmp/wlroots-$wlrver"
	[ -d "$src" ] || die "the wlroots release did not unpack where it should ($src)"
	say "  building (a few minutes)"
	# The run path is written into what is built, so DEsk finds this wlroots and
	# nothing else on the system does: its libraries are not on ld.so's list.
	# shellcheck disable=SC2086
	meson setup "$src/_build" "$src" --prefix="$wlr" --libdir=lib --buildtype=release \
		$wlropts -Dc_link_args="-Wl,-rpath,$wlr/lib" > "$tmp/wlroots.log" 2>&1 \
		|| { cat "$tmp/wlroots.log"; die "Meson could not set up wlroots $wlrver (above)"; }
	meson compile -C "$src/_build" > "$tmp/wlroots.log" 2>&1 \
		|| { tail -n 40 "$tmp/wlroots.log"; die "wlroots $wlrver did not build (above)"; }
	as_root meson install -C "$src/_build" --no-rebuild --quiet > "$tmp/wlroots.log" 2>&1 \
		|| { cat "$tmp/wlroots.log"; die "wlroots $wlrver did not install into $wlr (above)"; }
	have_wlroots || die "wlroots $wlrver is not to be found in $wlr after building it, or was built without Xwayland"
	say "  wlroots $wlrver: built and installed."
fi

# -- 3. DEsk ----------------------------------------------------------------
step "DEsk"
# scripts/install.sh builds DEsk and installs it, and puts it on the login
# screen. Meson reads where wlroots is, and the run path DEsk is to carry,
# from the environment the first time it sets a build folder up.
PKG_CONFIG_PATH="$pcpath${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
LDFLAGS="-Wl,-rpath,$wlr/lib${LDFLAGS:+ $LDFLAGS}"
export PKG_CONFIG_PATH LDFLAGS
BUILD_DIR="$build"
export BUILD_DIR
# a build folder set up before may not have been told about either; it is only a build
rm -rf "$build" 2>/dev/null || as_root rm -rf "$build"
sh "$root/scripts/install.sh" --prefix "$prefix" || die "DEsk did not build or install (above)"

# -- 4. is it the wlroots it was built for ------------------------------------
step "Checking"
if [ -x "$prefix/bin/desk" ]; then
	if ldd "$prefix/bin/desk" 2>/dev/null | grep -q "libwlroots-0.18.so.*$wlr/lib"; then
		say "  $prefix/bin/desk finds wlroots $wlrver in $wlr: good."
	else
		say "  Note: $prefix/bin/desk does not seem to find wlroots in $wlr. What it finds:"
		ldd "$prefix/bin/desk" 2>/dev/null | grep -i wlroots | sed 's/^/    /' || true
	fi
fi
say
say "Next:"
say "  - try it as a window first:   desk -s xfce4-terminal   (or any terminal)"
say "  - the programs DEsk is meant to be used with (file manager, editor, ...):"
say "      sh scripts/install-desktop.sh"
say "    and what each row of Shell Settings would open:   desk-settings --check"
say "  - something wrong: ~/.local/state/desk/session.log"
