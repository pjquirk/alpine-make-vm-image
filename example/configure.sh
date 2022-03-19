#!/bin/sh

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

step 'Download WALinuxAgent'
wget https://github.com/Azure/WALinuxAgent/archive/v2.7.0.6.zip
unzip v2.7.0.6.zip
cd WALinuxAgent-2.7.0.6

step 'Install WALinuxAgent'
apk add openssl sudo bash shadow parted iptables sfdisk
apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
python3 -m ensurepip
pip3 install --no-cache --upgrade pip setuptools
pip install distro
python setup.py install
sed -i 's/# AutoUpdate.Enabled=n/AutoUpdate.Enabled=y/g' /etc/waagent.conf
waagent -help
waagent -version

step 'Generalize'
sudo waagent -deprovision+user -force

# Update boot params
sed -i 's/^default_kernel_opts="[^"]*/\0 console=ttyS0 earlyprintk=ttyS0 rootdelay=300/' /etc/update-extlinux.conf
update-extlinux

# sshd configuration
sed -i 's/^#ClientAliveInterval 0/ClientAliveInterval 180/' /etc/ssh/sshd_config

# Start waagent at boot
cat > /etc/init.d/waagent <<EOF
#!/sbin/openrc-run                                                                 
export PATH=/usr/local/sbin:$PATH
start() {                                                                          
        ebegin "Starting waagent"                                                  
        start-stop-daemon --start --exec /usr/sbin/waagent --name waagent -- -start
        eend $? "Failed to start waagent"                                          
}
EOF

chmod +x /etc/init.d/waagent
rc-update add waagent default

# Workaround for default password
# Basically, useradd on Alpine locks the account by default if no password
# was given, and the user can't login, even via ssh public keys. The useradd.sh script
# changes the default password to a non-valid but non-locking string.
# The useradd.sh script is installed in /usr/local/sbin, which takes precedence
# by default over /usr/sbin where the real useradd command lives.
mkdir -p /usr/local/sbin

cat > /usr/local/sbin/useradd <<EOF
#!/bin/sh

/usr/sbin/useradd $*

# if success...
if [ $? == 0 ]; then
        # was the passwd set in the command?
        passwd_set=
        for i in "$@"; do
                if [ $i == "-p" -o $i == "--password" ]; then
                        passwd_set=0
                fi
        done
        # if the passwd was set, don't mess with it
        # if no passwd was set, replace the default "!" with "*"
        # (still invalid password, but the account is not locked for ssh)
        if [ $passwd_set ]; then
                echo "useradd: password was set, doing nothing"
        else
                echo "useradd: force default password"
                for login; do true; done
                usermod -p "*" $login
        fi
fi
EOF
chmod +x /usr/local/sbin/useradd
