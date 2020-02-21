#!/usr/bin/env bash

set -eo pipefail

[ -n "$DOCHAT_DEBUG" ] && set -x

#
# WeChat
#
function startWechat () {
  if [ -n "$DOCHAT_DEBUG" ]; then
    wine reg query 'HKEY_CURRENT_USER\Software\Tencent\WeChat' || echo 'Register for Wechat not found ?'
  fi

  while true; do
    echo
    echo '[DoChat] Starting...'
    echo

    if [ -n "$DOCHAT_DEBUG" ]; then
      wine 'C:\Program Files\Tencent\WeChat\WeChat.exe'
    else
      if ! wine 'C:\Program Files\Tencent\WeChat\WeChat.exe' 2> /dev/null; then
        echo "[DoChat] WeChat.exe exited by itself"
      fi
    fi

    #
    # WeChat.exe will run background after an upgrade.
    # Check if it exists, and wait it exit.
    #
    while true; do
      if [ -n "$(pgrep -i WeChat.exe)" ]; then
        sleep 1
      else
        echo '[DoChat] WeChat.exe exited'
        break
      fi
    done

    #
    # Wait until it finish
    #   if there's a running upgrading process
    #
    unset upgrading
    while true; do
      # pgrep returns nothing if the pattern length is longer than 15 characters
      # https://askubuntu.com/a/813214/375372
      # WeChatUpdate.exe -> WeChatUpdate.ex
      if [ -z "$(pgrep -i WeChatUpdate.ex)" ]; then
        break
      fi

      if [ -z "$upgrading" ]; then
        echo -n '[DoChat] Upgrading...'
        upgrading=true
      fi

      echo -n .
      sleep 1

    done

    # if it's not upgrading, then quit upgrading check loop
    if [ -z "$upgrading" ]; then
      break
    fi

    # go to loop beginning and restart wine again.
  done
}

function setupUserGroup () {
  if [ -n "$AUDIO_GID" ]; then
    groupmod -o -g "$AUDIO_GID" audio
  fi
  if [ -n "$VIDEO_GID" ]; then
    groupmod -o -g "$VIDEO_GID" video
  fi
  if [ "$GID" != "$(id -g user)" ]; then
      groupmod -o -g "$GID" group
  fi
  if [ "$UID" != "$(id -u user)" ]; then
      usermod -o -u "$UID" user
  fi

  chown user:group \
    '/home/user/.wine/drive_c/users/user/Application Data' \
    '/home/user/WeChat Files'
}

function setupHostname () {
  export HOSTNAME=DoChat
  echo "$HOSTNAME" > /etc/hostname

  #
  # Change the hostname for the wine runtime
  # --privileged required
  #
  hostname "$HOSTNAME"
}

#
# Main
#
function main () {
  if [ "$(id -u)" -ne '0' ]; then
    startWechat
  else
    setupUserGroup
    setupHostname
    #
    # Switch to user:group, and re-run self to run user task
    #
    exec gosu user "$0" "$@"
  fi
}

main "$@"