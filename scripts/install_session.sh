#!/bin/sh
# install_session.sh -- DEsk on this machine, in one go.
#
# Finds out which Linux this is and runs the installer for it:
#
#   Debian 13 (and what is built on it)        scripts/install_debian.sh
#   Ubuntu 24.04 / 26.04 (Mint, Pop!_OS...)    scripts/install_ubuntu.sh
#   Arch Linux (EndeavourOS, Manjaro...)       scripts/install_arch.sh
#   Kali Linux (rolling: wlroots too new)      scripts/install_kali.sh
#   Fedora 43 and later (Nobara...)            scripts/install_fedora.sh
#
# The installers take the same options, and everything you give this is handed
# on as it is:
#
#   --yes          do not ask; take the answers it would suggest
#   --no-apps      only DEsk, what it needs and the programs its Shell Settings
#                  opens, not the other recommended programs
#   --bare         only DEsk and what it needs: no programs (for a container)
#   --prefix DIR   where DEsk goes (default /usr/local)
#   --help         this, and what the installer for this machine does
#
# Run it as yourself from the folder you got DEsk in; it asks for sudo
# when it needs to. When it is done, log out and pick "DEsk" on the login
# screen. To update, get the new copy and run it again the same way: what
# is installed is replaced, the build left from the last time is reused
# (or made afresh if it cannot be), and your settings stay as they are.
# All it says is kept in ~/.local/state/desk/install.log as well, the last
# run's: when something goes wrong, that is the thing to look at, or send.
# A copy with SHA256SUMS in it is checked first, file by file: one that
# came out damaged on its way here is said to be, not built.
#
# On another Linux, install what the README lists and run scripts/install.sh,
# which builds and installs DEsk the same way, and scripts/install-desktop.sh
# for the programs.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"

help=no
for a in "$@"; do
	case "$a" in
	-h|--help) help=yes ;;
	esac
done
if [ "$help" = yes ]; then
	sed -n '2,/^set /s/^# \{0,1\}//p' "$0"
	echo
fi

if [ ! -r /etc/os-release ]; then
	echo "install_session.sh: there is no /etc/os-release, so which Linux this is is not known." >&2
	echo "Run scripts/install_debian.sh, install_ubuntu.sh, install_arch.sh, install_fedora.sh or install_kali.sh yourself." >&2
	exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

# what it is, then what it says it is like
which=""
for id in ${ID:-} ${ID_LIKE:-}; do
	case "$id" in
	ubuntu) which=ubuntu ;;
	kali) which=kali ;;
	debian) which=debian ;;
	arch|archlinux) which=arch ;;
	fedora) which=fedora ;;
	*) continue ;;
	esac
	break
done

name="${PRETTY_NAME:-${ID:-this Linux}}"
if [ -z "$which" ]; then
	echo "install_session.sh: $name is not one DEsk has an installer for." >&2
	echo "There is one for Debian 13, Ubuntu 24.04 and 26.04, Arch Linux and Fedora. Here, install" >&2
	echo "what the README lists, then scripts/install.sh builds and installs DEsk and" >&2
	echo "scripts/install-desktop.sh brings the programs that go with it." >&2
	exit 1
fi

script="$here/install_$which.sh"
if [ ! -f "$script" ]; then
	echo "install_session.sh: $script is missing from this copy of DEsk." >&2
	exit 1
fi
# asked only what it does: the installer for this machine says too, and
# nothing is checked, run or written down
if [ "$help" = yes ]; then
	exec sh "$script" --help
fi
# A copy carried from one machine to another can come out damaged -- a
# stick pulled out too soon, a few bytes gone wrong on the way -- and then
# the build stops at some line that says nothing of why. A copy made for
# passing round carries SHA256SUMS, and every file is checked against it
# first. (A git checkout has none, and is not checked.)
top="$(cd "$here/.." && pwd)"
if [ -f "$top/SHA256SUMS" ] && command -v sha256sum >/dev/null 2>&1; then
	if ! damaged=$(cd "$top" && sha256sum --quiet -c SHA256SUMS 2>&1); then
		echo "install_session.sh: this copy of DEsk is damaged -- these files are not what" >&2
		echo "they were when it was made:" >&2
		printf '%s\n' "$damaged" | sed 's/^/  /' >&2
		echo "Copy the folder again (from a USB stick: eject it before pulling it out)." >&2
		echo "If a fresh copy comes out damaged too, suspect the machine's memory or disk:" >&2
		echo "memtest86+ (a choice in the boot menu once it is installed) tests the memory." >&2
		exit 1
	fi
	echo "DEsk: every file of this copy checked against SHA256SUMS."
	# (and the installer it runs need not check them again)
	DESK_SUMS_CHECKED=1
	export DESK_SUMS_CHECKED
fi

# Everything the installer says is kept as well as shown
logdir="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/desk"
mkdir -p "$logdir" 2>/dev/null || logdir="${TMPDIR:-/tmp}"
log="$logdir/install.log"

echo "DEsk: this is $name -- running $(basename "$script")"
for d in /usr/local /usr; do
	if [ -x "$d/bin/desk" ]; then
		echo "DEsk is installed already ($d/bin/desk): this updates it."
		break
	fi
done
echo "All it says is kept in $log as well."
echo
rcf=$(mktemp 2>/dev/null) || rcf="$logdir/install.rc"
# the installer's own exit, past tee (and past set -e, in the subshell)
{ rc=0; sh "$script" "$@" || rc=$?; echo "$rc" > "$rcf"; } 2>&1 | tee "$log"
rc=$(cat "$rcf" 2>/dev/null || echo 1)
rm -f "$rcf"
if [ "$rc" -ne 0 ]; then
	echo
	echo "DEsk: the installer stopped (exit $rc). All of what it said is in"
	echo "  $log"
	echo "-- what went wrong is usually in the last lines above."
fi
exit "$rc"
