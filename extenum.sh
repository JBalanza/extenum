#!/bin/bash

#OPTIONS
#For better results  you will have to fill the lists with the info you have
possible_usernames=(
	"root"
	"admin"
)

possible_domains=(
	'127.0.0.1'
	'localhost'
)

possible_network="192.168.0.0"

function check_dependencies() {
	dependencies_commands=(
		"apt"
		"host"
		"dig"
		"nslookup"
		"dnsrecon"
		"nbtscan"
		"smbclient"
		"mount"
		"msfconsole"
		"nmap"
		"cut"
		"readarray"
	)

	dependencies_packets=(
		"cifs-utils"
	)

	echo "Start Checking you have all we need to start..."

	have_all_dependencies=0
	for i in "${dependencies_commands[@]}"; do
		if ! hash "$i" 2>/dev/null; then
			print_error "You've not installed the following dependency: $i"
			have_all_dependencies=1
		fi
		echo "Checked you have ${i} installed"
	done

	have_all_packets=0
	apt_list="$(apt list 2>/dev/null)"
	for j in "${dependencies_packets[@]}"; do
		echo "${apt_list}" | grep -E "$j" &>/dev/null
		if [ "$?" -ne 0 ]; then
			print_error "You've not installed the following packets: $j"
			have_all_packets=1
		fi
		echo "Checked you have ${j} installed"
	done

	if [[ "${have_all_dependencies}" -eq 1 ]] || [[ "${have_all_packets}" -eq 1 ]]; then
		print_error "Please install the missing dependencies before continuing"
		exit 1
	fi
}

function print_error() {
	echo -e "\e[31m$1\e"
	echo -e "\e[1;0m"
}

function print_green(){
	echo -e "\e[33m$1\e"
	echo -e "\e[1;0m"
}

function print_usage() {
	echo -e "Usage:\t" $0 "<device_ip_address>"
	exit 1
}

function parse_arguments() {
	#Parse IP adress
	ip="$1"
	echo "${ip}" | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" &>/dev/null
	if [ "$?" -ne 0 ]; then
		print_error "Bad ip address format"
		exit 1
	fi
}

function launch_nmap() {
	#TODO detect also UDP
	echo -e "\nLaunching Nmap"

	nmap_command="nmap ${ip}"
	open_ports="$(${nmap_command} | grep -Eo '[0-9]{1,5}/tcp' | sed 's@/tcp@\n@g')"
	readarray -t OPEN_PORTS_ARRAY < <(echo "${open_ports}" 2> /dev/null) &>/dev/null
	echo -e "Finished. Discovered: ${OPEN_PORTS_ARRAY[*]}\n"
}

function perform_tests() {
	for port in "${OPEN_PORTS_ARRAY[@]}"; do
		case "${port}" in
			"53")
				for dom in "${possible_domains[@]}";do
					dns_checks "$dom" "${possible_network}"
				done
			;;
			"443"|"445")
				for user in "${possible_usernames[@]}"; do
					smb_checks "${user}" 
				done
			;;
			*)
				if [ ! -z "${port}" ];then
					print_error "\nNo tests programmed for ${port} port"
				fi
			;;
		esac


	done
}

###############     PROTOCOL TEST       ###########
function dns_checks() {
	#Use a list of domains. Taken as input if transferzone is possible
	echo '**** DNS CHECKS'
	echo 'Check: Zone transfer'
	command="host -l $1 ${ip}"
	print_green "Test: ${command}"
	eval "${command}"

	command="dig axfr $1 @${ip}"
	print_green "Test: ${command}"
	eval "${command}"

	command="dnsrecon -r $2/24 -n ${ip}"
	print_green "Test: ${command}"
	eval "${command}"
	
	

}

function smb_checks() {
	echo '**** SMB CHECKS'
	echo 'Check: SMB shared folders'
	command="msfconsole -x \" use auxiliary/scanner/smb/smb_version; set RHOSTS ${ip}; run; exit\""
	print_green "Test: ${command}"
	eval "${command}" | grep "${ip}"

	command="smbclient -L ${ip} -U=root%toor "
	print_green "Test: ${command}"
	eval "${command}"

}

function main() {
	check_dependencies
	parse_arguments "$@"
	launch_nmap
	perform_tests
}

################      MAIN      ################

if [ "$#" -eq 0 ]; then
	echo "This scrip perform several test on common open ports"
	print_usage
elif [ "$#" -ne 1 ]; then
	print_error "Bad number of arguments."
	print_usage
fi

main "$@"

