#!/bin/sh
set -ex

_step_counter=0
step() {
	_step_counter=$(( _step_counter + 1 ))
	printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

step 'Set up timezone'
setup-timezone -z Europe/Prague

step 'Set up networking'
cat > /etc/network/interfaces <<-EOF
	iface lo inet loopback
	iface eth0 inet dhcp
EOF
ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

step 'Adjust rc.conf'
sed -Ei \
	-e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
	-e 's/^[# ](rc_logger)=.*/\1=YES/' \
	-e 's/^[# ](unicode)=.*/\1=YES/' \
	/etc/rc.conf

step 'Enable services'
rc-update add acpid default
rc-update add chronyd default
rc-update add crond default
rc-update add net.eth0 default
rc-update add net.lo boot
rc-update add termencoding boot

# step 'Download WALinuxAgent'
# rm -f v2.7.0.6.zip
# wget https://github.com/Azure/WALinuxAgent/archive/v2.7.0.6.zip
# unzip -o v2.7.0.6.zip
# cd WALinuxAgent-2.7.0.6

# step 'Install WALinuxAgent'
# Community package required for shadow
# echo "http://dl-cdn.alpinelinux.org/alpine/v3.6/community" >> /etc/apk/repositories

# apk add openssl sudo bash shadow parted iptables sfdisk
# apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
# python3 -m ensurepip
# pip3 install --no-cache --upgrade pip setuptools
# pip install distro
# python setup.py install
# sed -i 's/# AutoUpdate.Enabled=n/AutoUpdate.Enabled=y/g' /etc/waagent.conf
# waagent -help
# waagent -version

# step 'Update boot params'
# sed -i 's/^default_kernel_opts="[^"]*/\0 console=ttyS0 earlyprintk=ttyS0 rootdelay=300/' /etc/update-extlinux.conf
# update-extlinux

# sshd configuration
# step 'sshd configuration'
# sed -i 's/^#ClientAliveInterval 0/ClientAliveInterval 180/' /etc/ssh/sshd_config

# Start waagent at boot
# step 'Configure waagent to start at boot'
# cat > /etc/init.d/waagent <<EOF
# #!/sbin/openrc-run
# export PATH=/usr/local/sbin:$PATH
# start() {
#         ebegin "Starting waagent"
#         start-stop-daemon --start --exec /usr/sbin/waagent --name waagent -- -start
#         eend $? "Failed to start waagent"
# }
# EOF

# chmod +x /etc/init.d/waagent
# rc-update add waagent default

# step 'Generalize'
# sudo waagent -deprovision+user -force

step 'List /usr/local/bin'
ls -la /usr/local/bin
