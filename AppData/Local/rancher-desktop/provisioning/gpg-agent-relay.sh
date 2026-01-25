#!/usr/bin/env bash
# from https://gist.github.com/Speedy37/1833b6b8c73a7768a266f0b903ab3678?permalink_comment_id=4491118#gistcomment-4491118
# Inspired by https://blog.nimamoh.net/yubi-key-gpg-wsl2/

# Guide:
# Install GPG on windows & Unix
# Add "enable-putty-support" to gpg-agent.conf
# Download wsl-ssh-pageant and npiperelay and place the executables in "C:\Users\[USER]\AppData\Roaming\" under wsl-ssh-pageant & npiperelay
# https://github.com/benpye/wsl-ssh-pageant/releases/tag/20190513.14
# https://github.com/NZSmartie/npiperelay/releases/tag/v0.1
# Adjust relay() below if you alter those paths
# Place this script in WSL at ~/.local/bin/gpg-agent-relay
# Start it on login by calling it from your .bashrc: "$HOME/.local/bin/gpg-agent-relay start"

# In a newer WSL installation the socket folder changed from the $HOME/.gnupg to the /run/user/1000
# the active folder can be identified with the `gpgconf --list-dirs` command
# GNUPGHOME="$HOME/.gnupg"
export GNUPGHOME="$HOME/.gnupg"
PIDFILE="$GNUPGHOME/gpg-agent-relay.pid"

die() {
  # shellcheck disable=SC2059
  printf "$1\n" >&2
  exit 1
}

main() {
  checkdeps
  case $1 in
  start)
    if ! start-stop-daemon --pidfile "$PIDFILE" --background --make-pidfile --exec "$0" --start -- foreground; then
      die 'Failed to start. Run `gpg-agent-relay foreground` to see output.'
    fi
    ;;
  stop)
    start-stop-daemon --pidfile "$PIDFILE" --stop
    rm -f "$PIDFILE" ;;
  status)
    start-stop-daemon --pidfile "$PIDFILE" --status
    local result=$?
    case $result in
      0) printf "gpg-agent-relay is running\n" ;;
      1 | 3) printf "gpg-agent-relay is not running\n" ;;
      4) printf "unable to determine status\n" ;;
    esac
    return $result
    ;;
  foreground)
    rm -f "$PIDFILE"
    rm -r /root/.gnupg/S.*
    relay ;;
  *)
    die "Usage:\n  gpg-agent-relay start\n  gpg-agent-relay stop\n  gpg-agent-relay status\n  gpg-agent-relay foreground" ;;
  esac
}

relay() {
  set -e
  local appdatafolder
  local localappdatafolder
  localappdatafolder=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe '$env:LocalAppData')
  localappdatafolder=${localappdatafolder//\\/\/}
  localappdatafolder=${localappdatafolder//$'\r'}
  appdatafolder=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe '$env:AppData')
  appdatafolder=${appdatafolder//\\/\/}
  appdatafolder=${appdatafolder//C:/\/mnt\/c}
  appdatafolder=${appdatafolder//$'\r'}
  homefolder=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe '$env:USERPROFILE')
  homefolder=${homefolder//\\/\/}
  homefolder=${homefolder//C:/\/mnt\/c}
  homefolder=${homefolder//$'\r'}
  local wingnupghome="${localappdatafolder}/gnupg"
  local npiperelay="${homefolder}/bin/npiperelay.exe"
  local wslsshpageant="${homefolder}/bin/wsl-ssh-pageant-amd64-gui.exe"
  local gpgconnectagent="/mnt/c/Program Files/GnuPG/bin/gpg-connect-agent.exe"

  local gpgagentsocket
  local sshagentsocket
  gpgagentsocket=$(gpgconf --list-dirs agent-socket 2>/dev/null || echo "$GNUPGHOME/S.gpg-agent")
  sshagentsocket=$(gpgconf --list-dirs agent-ssh-socket 2>/dev/null || echo "$GNUPGHOME/S.gpg-agent.ssh")

  killsocket "$gpgagentsocket"
  killsocket "$sshagentsocket"

  "$gpgconnectagent" /bye

  "$wslsshpageant" --systray --winssh ssh-pageant 2>/dev/null &
  WSPPID=$!

  socat UNIX-LISTEN:"$gpgagentsocket,unlink-close,fork,umask=177" EXEC:"$npiperelay -ep -ei -s -a '${wingnupghome}/S.gpg-agent'",nofork &
  GNUPID=$!
  # shellcheck disable=SC2064
  trap "kill -TERM $GNUPID" EXIT

  socat UNIX-LISTEN:"$sshagentsocket,unlink-close,fork,umask=177" EXEC:"$npiperelay /\/\./\pipe/\ssh-pageant" &
  SSHPID=$!

  set +e
  # shellcheck disable=SC2064
  trap "kill -TERM $GNUPID; kill -TERM $SSHPID" EXIT

  systemd-notify --ready 2>/dev/null
  wait $GNUPID $SSHPID
  trap - EXIT
}

killsocket() {
  local socketpath=$1
  if [[ -e $socketpath ]]; then
    local socketpid
    if socketpid=$(lsof +E -taU -- "$socketpath"); then
      timeout .5s tail --pid=$socketpid -f /dev/null &
      local timeoutpid=$!
      kill "$socketpid"
      if ! wait $timeoutpid; then
        die "Timed out waiting for pid $socketpid listening at $socketpath"
      fi
    else
      rm "$socketpath"
    fi
  fi
}

checkdeps() {
  local deps=(socat start-stop-daemon lsof timeout)
  local dep
  local out
  for dep in "${deps[@]}"; do
    if ! out=$(type "$dep" 2>&1); then
      printf -- "Dependency %s not found:\n%s\n" "$dep" "$out"
      return 1
    fi
  done
}

main "$@"
