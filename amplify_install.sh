#!/bin/sh
#
# NGINX Amplify Agent install script
#
# Copyright (C) 2015 Nginx, Inc.
#

packages_url="http://packages.amplify.nginx.com"
package_name="nginx-amplify-agent"
public_key_url="http://nginx.org/keys/nginx_signing.key"
agent_conf_path="/etc/amplify-agent"
agent_conf_file="${agent_conf_path}/agent.conf"

#
# Functions
#

# Get OS information
get_os_name () {

    centos_flavor="centos"

    # Use lsb_release if possible
    if command -V lsb_release > /dev/null 2>&1; then
	os=`lsb_release -is | tr '[:upper:]' '[:lower:]'`
	codename=`lsb_release -cs | tr '[:upper:]' '[:lower:]'`
	release=`lsb_release -rs | sed 's/\..*$//'`

	if [ "$os" = "redhatenterpriseserver" ]; then
	    os="centos"
	    centos_flavor="red hat"
	fi
    # Otherwise it's getting a little bit more tricky
    else
	if ! ls /etc/*-release > /dev/null 2>&1; then
	    os=`uname -s | \
		tr '[:upper:]' '[:lower:]'`
	else
	    os=`cat /etc/*-release | grep '^ID=' | \
		sed 's/^ID=["]*\([a-zA-Z]*\).*$/\1/' | \
		tr '[:upper:]' '[:lower:]'`

	    if [ -z "$os" ]; then
		if grep -i "centos" /etc/*-release; then
		    os="centos"
		else
		    os="linux"
		fi
	    fi
	fi

	case "$os" in
	    ubuntu)
		codename=`cat /etc/*-release | grep '^DISTRIB_CODENAME' | \
			  sed 's/^[^=]*=\([^=]*\)/\1/' | \
			  tr '[:upper:]' '[:lower:]'`
		;;
	    debian)
		codename=`cat /etc/*-release | grep '^VERSION=' | \
			  sed 's/.*(\(.*\)).*/\1/' | \
			  tr '[:upper:]' '[:lower:]'`
		;;
	    centos)
		codename=`cat /etc/*-release | grep -i 'centos.*(' | \
			  sed 's/.*(\(.*\)).*/\1/' | head -1 | \
			  tr '[:upper:]' '[:lower:]'`
		# For CentOS grab release
		release=`cat /etc/*-release | grep -i 'centos.*[0-9]' | \
			 sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1`
		;;
	    rhel)
		codename=`cat /etc/*-release | grep -i 'red hat.*(' | \
			  sed 's/.*(\(.*\)).*/\1/' | head -1 | \
			  tr '[:upper:]' '[:lower:]'`
		# For Red Hat also grab release
		release=`cat /etc/*-release | grep -i 'red hat.*[0-9]' | \
			 sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1`

		if [ -z "$release" ]; then
		    release=`cat /etc/*-release | grep -i '^VERSION_ID=' | \
			     sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1`
		fi

		os="centos"
		centos_flavor="red hat"
		;;
	    amzn)
		codename="amazon-linux-ami"
		release_amzn=`cat /etc/*-release | grep -i 'amazon.*[0-9]' | \
			 sed 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*$/\1/' | \
			 head -1`

		if [ "$python_27" = "yes" ]; then
		    release="7"
		else
		    release="6"
		fi

		# Amazon Linux is basically a flavor of CentOS
		os="centos"
		centos_flavor="amazon linux"
		;;
	    *)
		codename=""
		release=""
		;;
	esac
    fi
}

# Check what downloader is available
check_downloader() {
    if command -V curl > /dev/null 2>&1; then
	downloader="curl -fs"
    else
	if command -V wget > /dev/null 2>&1; then
	    downloader="wget -q -O -"
	else
	    printf "\033[31m no curl or wget found, exiting.\033[0m\n\n"
	    exit 1
	fi
    fi
}

# Add public key for package verification (Ubuntu/Debian)
add_public_key_deb() {
    printf "\033[32m ${step}. Adding public key ...\033[0m"

    check_downloader && \
    ${downloader} ${public_key_url} | \
    ${sudo_cmd} apt-key add - > /dev/null 2>&1

    if [ $? -ne 0 ]; then
	printf "\033[31m failed.\033[0m\n\n"
	exit 1
    else
	printf "\033[32m done.\033[0m\n"
    fi
}

# Add public key for package verification (CentOS/Red Hat)
add_public_key_rpm() {
    printf "\033[32m ${step}. Adding public key ...\033[0m"

    if command -V rpmkeys > /dev/null 2>&1; then
	rpm_key_cmd="rpmkeys"
    else
	rpm_key_cmd="rpm"
    fi

    check_downloader && \
    ${sudo_cmd} rm -f /tmp/nginx_signing.key.$$ && \
    ${downloader} ${public_key_url} | \
    tee /tmp/nginx_signing.key.$$ > /dev/null 2>&1 && \
    ${sudo_cmd} ${rpm_key_cmd} --import /tmp/nginx_signing.key.$$ && \
    rm -f /tmp/nginx_signing.key.$$

    if [ $? -ne 0 ]; then
	printf "\033[31m failed.\033[0m\n\n"
	exit 1
    else
	printf "\033[32m done.\033[0m\n"
    fi
}

# Add repo configuration (Ubuntu/Debian)
add_repo_deb () {
    printf "\033[32m ${step}. Adding repository ...\033[0m"

    test -d /etc/apt/sources.list.d && \
    ${sudo_cmd} test -w /etc/apt/sources.list.d && \
    ${sudo_cmd} rm -f /etc/apt/sources.list.d/amplify-agent.list && \
    ${sudo_cmd} rm -f /etc/apt/sources.list.d/nginx-amplify.list && \
    echo "deb ${packages_url}/${os}/ ${codename} amplify-agent" | \
    ${sudo_cmd} tee /etc/apt/sources.list.d/nginx-amplify.list > /dev/null 2>&1 && \
    ${sudo_cmd} chmod 644 /etc/apt/sources.list.d/nginx-amplify.list > /dev/null 2>&1

    if [ $? -eq 0 ]; then
	printf "\033[32m added.\033[0m\n"
    else
	printf "\033[31m failed.\033[0m\n\n"
	exit 1
    fi
}

# Add repo configuration (CentOS)
add_repo_rpm () {
    printf "\033[32m ${step}. Adding repository config ...\033[0m"

    test -d /etc/yum.repos.d && \
    ${sudo_cmd} test -w /etc/yum.repos.d && \
    ${sudo_cmd} rm -f /etc/yum.repos.d/nginx-amplify.repo && \
    printf "[nginx-amplify]\nname=nginx amplify repo\nbaseurl=${packages_url}/${os}/${release}/\$basearch\ngpgcheck=1\nenabled=1\n" | \
    ${sudo_cmd} tee /etc/yum.repos.d/nginx-amplify.repo > /dev/null 2>&1 && \
    ${sudo_cmd} chmod 644 /etc/yum.repos.d/nginx-amplify.repo > /dev/null 2>&1

    if [ $? -eq 0 ]; then
	printf "\033[32m added.\033[0m\n"
    else
	printf "\033[31m failed.\033[0m\n\n"
	exit 1
    fi
}

# Install package (either deb or rpm)
install_deb_rpm() {
    # Update repo
    printf "\033[32m ${step}. Updating repository ...\n\n\033[0m"

    test -n "$update_cmd" && \
    ${sudo_cmd} ${update_cmd}

    if [ $? -eq 0 ]; then
	printf "\033[32m\n ${step}. Updating repository ... done.\033[0m\n"
    else
	printf "\033[31m\n ${step}. Updating repository ... failed.\033[0m\n\n"
	exit 1
    fi

    step=`expr $step + 1`

    # Install package(s)
    printf "\033[32m ${step}. Installing package ...\033[0m\n\n"

    test -n "$package_name" && \
    test -n "$install_cmd" && \
    ${sudo_cmd} ${install_cmd} ${package_name}

    if [ $? -eq 0 ]; then
	printf "\n\033[32m ${step}. Installing package ... done.\033[0m\n"
    else
	printf "\033[32m ${step}. Installing package ... failed.\033[0m\n\n"
	exit 1
    fi
}


#
# Main
#

step=1

printf "\033[32m\n This script will install NGINX Amplify Agent \n\n\033[0m"
printf "\033[32m ${step}. Checking user ...\033[0m"

# Detect root
if [ "`id -u`" = "0" ]; then
    sudo_cmd=""
else
    if command -V sudo > /dev/null 2>&1; then
	sudo_cmd="sudo "
    else
	printf "\033[33m not root, sudo not found, exiting.\033[0m\n"
	exit 1
    fi
fi

if [ "$sudo_cmd" = "sudo " ]; then
    printf "\033[33m you'll need sudo rights.\033[0m\n"
else
    printf "\033[32m root, ok.\033[0m\n"
fi

step=`expr $step + 1`

# Add API key
printf "\033[32m ${step}. Checking API key ...\033[0m"

if [ -n "$API_KEY" ]; then
    api_key=$API_KEY
fi

if [ -z "$api_key" ]; then
    printf "\033[31m What's your API key? Please check the docs and the UI.\033[0m\n\n"
    exit 1
else
    printf "\033[32m using ${api_key}\033[0m\n"
fi

step=`expr $step + 1`

# Check for Python
printf "\033[32m ${step}. Checking python version ...\033[0m"
command -V python > /dev/null 2>&1 && python_exists='yes' || python_exists='no'
command -V python2.7 > /dev/null 2>&1 && python_27='yes' || python_27='no'
command -V python2.6 > /dev/null 2>&1 && python_26='yes' || python_26='no'

if [ "$python_exists" = "no" ]; then
    printf "\033[31m python is required, but couldn't be found.\033[0m\n\n"
    exit 1
fi

if [ "$python_27" = "no" -a $python_26 = "no" ]; then
    printf "\033[31m python is too old, require version >= 2.6.\033[0m\n\n"
    exit 1
fi

python_version=`python -c 'import sys; print("{0}.{1}".format(sys.version_info[0], sys.version_info[1]))'`
printf "\033[32m found python $python_version\033[0m\n"

step=`expr $step + 1`

# Check for supported OS
printf "\033[32m ${step}. Checking OS compatibility ...\033[0m"

# Get OS name and codename
get_os_name

# Add public key, create repo config, install package
case "$os" in
    ubuntu|debian)
	printf "\033[32m ${os} detected.\033[0m\n"

	step=`expr $step + 1`

	# Add public key
	add_public_key_deb

	step=`expr $step + 1`

	# Add repository configuration
	add_repo_deb

	step=`expr $step + 1`

	# Install package
	update_cmd="apt-get update"
	install_cmd="apt-get install"

	install_deb_rpm
	;;
    centos)
	printf "\033[32m ${centos_flavor} detected.\033[0m\n"

	step=`expr $step + 1`

	# Add public key
	add_public_key_rpm

	step=`expr $step + 1`

	# Add repository configuration
	add_repo_rpm

	step=`expr $step + 1`

	# Install package
	update_cmd="yum makecache"
	install_cmd="yum install"

	install_deb_rpm
	;;
   *)
	if [ -n "$os" ] && [ "$os" != "linux" ]; then
	    printf "\033[31m $os is currently unsupported, apologies!\033[0m\n\n"
	else
	    printf "\033[31m failed.\033[0m\n\n"
	fi

	exit 1
esac

step=`expr $step + 1`

# Build config file from template
printf "\033[32m ${step}. Building configuration file ...\033[0m"

if [ ! -f "${agent_conf_file}.default" ]; then
    printf "\033[31m can't find ${agent_conf_file}.default\033[0m\n\n"
    exit 1
fi

if [ -f "${agent_conf_file}" ]; then
    receiver=`cat ${agent_conf_file} | grep -i receiver | sed 's/^.*= \([^ ][^ ]*\)$/\1/'`
    ${sudo_cmd} rm -f ${agent_conf_file}.old
    ${sudo_cmd} cp -p ${agent_conf_file} ${agent_conf_file}.old
fi

${sudo_cmd} rm -f ${agent_conf_file} && \
${sudo_cmd} sh -c "sed 's/api_key.*$/api_key = $api_key/' \
	${agent_conf_file}.default > \
	${agent_conf_file}" && \
${sudo_cmd} chmod 644 ${agent_conf_file} && \
${sudo_cmd} chown nginx ${agent_conf_file} > /dev/null 2>&1

if [ $? -eq 0 ]; then
    printf "\033[32m done.\033[0m\n\n"
else
    printf "\033[31m failed.\033[0m\n\n"
    exit 1
fi


# Add Hostname key
printf "\033[32m ${step}. Checking Hostname ...\033[0m"

if [ -n "$HOSTNAME" ]; then
    hostname=$HOSTNAME
	${sudo_cmd} cp ${agent_conf_file} ${agent_conf_file}.intermediate && \
	${sudo_cmd} rm -f ${agent_conf_file} && \
	${sudo_cmd} sh -c "sed 's/hostname.*$/hostname = $hostname/' \
		${agent_conf_file}.intermediate > \
		${agent_conf_file}" && \
	${sudo_cmd} chmod 644 ${agent_conf_file} && \
	${sudo_cmd} chown nginx ${agent_conf_file} > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		printf "\033[32m done.\033[0m\n\n"
	else
		printf "\033[31m failed.\033[0m\n\n"
		exit 1
	fi

fi

# Check if init.d script exists
if [ ! -x /etc/init.d/amplify-agent ]; then
    printf "\033[31m Error: /etc/init.d/amplify-agent not found!\033[0m\n\n"
    exit 1
fi

# Finalize install
printf "\033[32m OK, it looks like everything is ready.\033[0m\n\n"

printf "\033[32m To start and stop the agent type:\033[0m\n\n"
printf "\033[33m     # ${sudo_cmd}service amplify-agent start\033[0m\n"
printf "\033[33m     # ${sudo_cmd}service amplify-agent stop\033[0m\n\n"

printf "\033[32m Agent logs can be found in:\033[0m\n"
printf "\033[33m     /var/log/amplify-agent/agent.log\033[0m\n\n"

printf "\033[32m After the agent is launched, it might take up to 1 minute\033[0m\n"
printf "\033[32m for this system to appear in the Amplify UI.\033[0m\n\n"

# Check for an older version of the agent running
if command -V pgrep > /dev/null 2>&1; then
    agent_pid=`pgrep amplify-agent`
else
    agent_pid=`ps aux | grep -i '[a]mplify-agent' | awk '{print $2}'`
fi

if [ -n "$agent_pid" ]; then
    printf "\033[32m Stopping old amplify-agent, pid ${agent_pid}\033[0m\n"
    ${sudo_cmd} service amplify-agent stop > /dev/null 2>&1 < /dev/null
fi

# Launch agent
printf "\033[32m Launching amplify-agent ...\033[0m\n"
${sudo_cmd} service amplify-agent start > /dev/null 2>&1 < /dev/null

if [ $? -eq 0 ]; then
    printf "\033[32m All done.\033[0m\n\n"
else
    printf "\033[31m Installation failed.\033[0m\n\n"
    exit 1
fi

exit 0
