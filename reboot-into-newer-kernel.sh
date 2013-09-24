#!/bin/sh

# notes
# - doesn't account for Oracle UEK packages
# - removes any kernels that aren't the running or newest-installed version
#
# sample use via root's crontab
# 
# 30 23 * * * yum -q -y update && $HOME/opsscripts/reboot-into-newer-kernel.sh

kernels() {
	rpm -qa --qf '%{INSTALLTIME} %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
		| awk '$2 ~ /^kernel-[0-9]/ { print }'
}

current() {
	echo -n "kernel-$(uname -r)"
}

newest() {
	kernels \
		| sort -n \
		| awk -vur="$(current)"  '{
			if($2 == ur) {
				show=1
			}
			if (show == 1) {
				print $2
			}
		}' \
		| tail -1 \
		| awk '{ print $1 }'
}

current="$(current)"
newest="$(newest)"

if [ "$current" != "$newest" ] ; then
	for kernel in $(kernels | awk '{ print $2 }') ; do
		if test "$current" != "$kernel" && test "$newest" != "$kernel" ; then
			echo "cleaning up old kernel: $kernel"
			yum -q -y remove $kernel
			echo
		fi
	done
	echo "rebooting into updated kernel: $newest"
	reboot
fi
