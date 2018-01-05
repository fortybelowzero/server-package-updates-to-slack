# Server package updates/installs sent as Slack Notifications

Cron-able Bash Script to identify new [ yum | apt-get ] updates and installations on a server and send them as a notification to Slack.

I created this to better track when package updates had been automatically installed on a server, with a view to spotting
when a service or server needs restarting to make use of security updates etc.

## Pre-requistes

This script will run under RHEL/Centos and Ubuntu (it will detect which and use either rpm (Yum on Redhat/Centos) or /var/log/dpkg.log (apt-get on Ubuntu). Other Distros are not supported, tho feel free to send a Pull request if you amend this.

Cron && Curl.

You need to have your server configured to automatically download and apply updates already (eg yum-cron). This script will not restart services/servers itself - its just notifying you that you may need to restart things yourself.

## Installation

Place the script somewhere suitable - i use /opt/fortybelowzero/server-package-updates-to-slack/

Change the configuration settings in the script. If currently expects SLACK_HOOK_URL to be an environment variable on your server, but you can uncomment and define it in the script if you so wish. Make a note of the frequence (default is every 15 mins).

Set up the script as a cron job. Note that the cron frequency needs to match the frequency setting in the script config.
I use the following cron entry:
```
*/15 * * * * /bin/bash /opt/fortybelowzero/server-package-updates-to-slack/server-package-updates-to-slack.sh >> /var/log/server-package-updates-to-slack.log 2>&1
```
## Disclaimer

My bash-fu is a little rusty - if there's a better way of writing/improving bits of it please let me know :-)
Use this script at your own risk. I've had no problems with it, but I can't guarantee it will never fail.

## Credits
Written by Rick Harrison : https://www.fortybelowzero.com ( @sovietuk on twitter )
