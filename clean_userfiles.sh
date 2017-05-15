#!/bin/bash
export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [ -f "/usr/local/cpanel/bin/cpuwatch" ]; then
	cores=`egrep -c processor /proc/cpuinfo`
	cpuwatch="/usr/local/cpanel/bin/cpuwatch $cores"
fi
timeout=`which timeout 2> /dev/null`
if [ -f "$timeout" ]; then
	find_prefix="timeout 300s $cpuwatch nice -n 19 ionice -c2 -n7"
else
	find_prefix="$cpuwatch nice -n 19 ionice -c2 -n7"
fi
usedbefore=`df -m /home | tail -n1 | awk '{print$3}'`

# delete easyapache/cpinstall folder
$find_prefix rm -rf /home/cpeasyapache /home/cPanelInstall

# delete cpanel/backup files, greater than 128MB, that are older than 7days
$find_prefix find /home /home1 /home2 /var/www/html /usr/local/apache/htdocs -maxdepth 3 -type f -mtime +7 -size +5M -regextype posix-extended -regex '.*(backup.*.tar.gz|cpmove.*.tar.gz)' -print0 2> /dev/null | xargs -0 rm -vf

for i in `awk -F':' '$3>=500' /etc/passwd | cut -d':' -f1,6 | sort`; do
	user=`echo $i | cut -d':' -f1`
	hdir=`echo $i | cut -d':' -f2`

	# empty user trash folders of contents older than 30d
	$find_prefix find ${hdir}/mail/*/*/{.Trash,.trash,.Spam,.spam} ${hdir}/*/mail/{.Trash,.trash,.Spam,.spam} -type f -mtime +14 -print0 2> /dev/null | xargs -0 rm -f

	# delte email older than 4 years
	$find_prefix find ${hdir}/mail/*/*/{cur,new} -mtime +1460 -type f -print0 2>&1 /dev/null | xargs -0 -P4 -I{} rm -f {} >> /dev/null

	# delete softaculous backups, that are older than 7days
	$find_prefix find ${hdir}/*/softaculous_backups -maxdepth 10 -type f -mtime +7 -regextype posix-extended -regex '.*.(tar.gz|gz|zip)' -print0 2> /dev/null | xargs -0 rm -vf
	$find_prefix find ${hdir}/*/softaculous_backups/tmp -maxdepth 1 -type d -mtime +1 -not -regex '.*/softaculous_backups/tmp$' -print0 2> /dev/null | xargs -0 rm -rf

	# delete common cms backups, error logs, bad backup plugin temp files -- older than 7days
	$find_prefix find ${hdir}/public_html -maxdepth 10 -type f -size +5M -mtime +7 -regextype posix-extended -regex '.*wc-logs.*.(log)|.*wp-content.*backup.*.(zip|tgz|tar|gz|sql)|.*wp-snapshots.*.(sql|zip)|.*/components/.*/backup/.*.(j[0-9]+|jpa$|zip|tgz|tar.gz)|.*/wp-content/updraft/*.(zip)|.*/var/report/[0-9]+$' -print0 2> /dev/null | xargs -0 rm -vf

	# delete core and error_log files
	$find_prefix find ${hdir}/public_html -maxdepth 8 -type f -size +1M -name "core.*" -regex '.*core..*[0-9]$' -print0 2> /dev/null | xargs -0 rm -vf
	$find_prefix find ${hdir}/public_html -maxdepth 8 -type f -size +1M -name "error_log" -regex '.*error_log$' -print0 2> /dev/null | xargs -0 rm -vf
done

usedafter=`df -m /home  | awk '{print$3}' | tail -n1`
diff=$[usedbefore-usedafter]
echo "cleaned ${diff}M of data from user paths"
