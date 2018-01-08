#!/bin/bash
#
# Monitoring of what packages have been updated/installed on a server automatically; Notification to a slack channel of whats been changed.
# We use this @GatenbySanderson to track what is automatically being updated on a server by cron'd yum && apt-get updates, they get posted
# to a monitored slack channel with the name of the server and what packages have been installed - we then decide if/when to schedule restarts
# of services or the server itself.
# 
# Setup:
# - Change values in the configuration section below
# - Add this as a cron-job - we run it every 15 minutes with this cron entry as root:
#   */15 * * * * /bin/bash /opt/fortybelowzero/server-package-updates-to-slack/server-package-updates-to-slack.sh >> /var/log/server-package-updates-to-slack.log 2>&1
# 
#   (assuming you place the script at /opt/fortybelowzero/server-package-updates-to-slack/server-package-updates-to-slack.sh )
#
# Author: Rick Harrison; 
# Version: 1.0.1  -- 6th January 2018
#
# Note: My bash-fu is a bit rusty - feel free to propose improvements to how this works!

# ==== CONFIGURATION =========================================================

# How often you are running this in cron (must match the same frequecy. This string needs to be in the format unix date command can parse, eg:
# 1 hour
# 2 hours
# 15 minutes
FREQUENCY="15 minutes"

# Slack Hook Url to post the slack message to. Commented out here as I set it on the server as an enviroment variable, you could either do that or
# uncomment and add your own Slack API Hook url here:
# SLACK_HOOK_URL="https://hooks.slack.com/services/foo/bar"

# Other Slack config settings.
SLACK_CHANNEL_NAME="#server-updates"
SLACK_POST_THUMBNAIL="https://i.imgur.com/3J4gkcPl.png"
SLACK_POST_USERNAME="updates-bot"

# Name of the server to use in the slack message title. By default below we're using the servers' own hostname, feel free to swap it to a 
# string if theres something you'd rather use to identify the server instead.
SERVERNAME=$(hostname)

# ==== END OF CONFIGURATION =========================================================

# distro-finding - try to work out what linux flavour we're under.
# Currently this script support redhat/centos and ubuntu. Feel free to PR amends to include other distros.
# Hat-tip: https://askubuntu.com/a/459425

UNAME=$(uname | tr "[:upper:]" "[:lower:]")
# If Linux, try to determine specific distribution
if [ "$UNAME" == "linux" ]; then
    # If available, use LSB to identify distribution
    if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
        export DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
    # Otherwise, use release info file
    else
        export DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)
    fi
fi
# For everything else (or if above failed), just use generic identifier
[ "$DISTRO" == "" ] && export DISTRO=$UNAME
unset UNAME

# /distro-finding

LASTFREQUENCY=$(date -d "$FREQUENCY ago" +"%s")
NOWTIME=$(date -d 'NOW'  +"%F")

# --------------- DEAL WITH PACKAGES INSTALLED IF LINUX DISTRIBUTION IS REDHAT OR CENTOS ------------------

if [[ ${DISTRO,,} == *"redhat"* ]] || [[ ${DISTRO,,} == *"centos"* ]] ; then
    rpm -qa --last | head -30 | while read -a linearray ; do
        PACKAGE=${linearray[0]}
        DATETIMESTR="${linearray[1]} ${linearray[2]} ${linearray[3]} ${linearray[4]} ${linearray[5]} ${linearray[6]}"
        INSTALLTIME=$(date --date="$DATETIMESTR" +"%s")
        if [ "$INSTALLTIME" -ge "$LASTFREQUENCY" ]; then
            echo "$PACKAGE    ($DATETIMESTR)\n" >> /tmp/package-updates-slack-announce.txt
        fi
    done

# --------------- DEAL WITH PACKAGES INSTALLED IF LINUX DISTRIBUTION IS UBUNTU ------------------

elif [[ ${DISTRO,,} == *"ubuntu"* ]] ; then

    cat /var/log/dpkg.log | grep "\ installed\ " | tail -n 30 | while read -a linearray ; do
        PACKAGE="${linearray[3]} ${linearray[4]} ${linearray[5]}"
        DATETIMESTR="${linearray[0]} ${linearray[1]}"
        INSTALLTIME=$(date --date="$DATETIMESTR" +"%s")
        if [ "$INSTALLTIME" -ge "$LASTFREQUENCY" ]; then
            echo "$PACKAGE    ($DATETIMESTR)\n" >> /tmp/package-updates-slack-announce.txt
        fi
    done
    
# --------------- OTHER LINUX DISTROS ARE UNTESTED - ABORT. ------------------    
else
    echo "ERROR: Untested/unsupported linux distro - Centos/Redhat/Ubuntu currently supported, feel free to amend for other distros and submit a PR."
fi

# --------------- IF PACKAGED WERE INSTALLED (THERES A TEMPORARY FILE WITH THEM LISTED IN IT) THEN SEND A SLACK NOTIFICATION. -------------
if [ -f /tmp/package-updates-slack-announce.txt ]; then

    echo "$NOWTIME - notifying updates to slack..."
    INSTALLATIONS=$(cat /tmp/package-updates-slack-announce.txt)
    curl -X POST --data-urlencode 'payload={"channel": "'"$SLACK_CHANNEL_NAME"'", "username": "'"$SLACK_POST_USERNAME"'", "attachments": [ { "fallback": "'"$INSTALLATIONS"'", "color": "good", "title": "UPDATES APPLIED ON '"$SERVERNAME"'", "text": "<!channel> Packages Updated:\n\n'"$INSTALLATIONS"'", "thumb_url": "'"$SLACK_POST_THUMBNAIL"'" } ] }' $SLACK_HOOK_URL
    rm -f /tmp/package-updates-slack-announce.txt
fi
