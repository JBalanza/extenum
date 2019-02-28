#!/bin/bash

#OPTIONS
#For better results  you will have to fill the lists with the info you have
possible_usernames=(
	"root"
	"admin"
	"guest"
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
		"enum4linux"
		"dirsearch"
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

function print_yellow(){
	echo -e "\e[33m$1\e"
	echo -e "\e[1;0m"

}

function print_usage() {
	echo -e "Usage:\t $0 <device_ip_address>"
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
	print_yellow "\nLaunching Nmap"

	nmap_command="nmap -sV ${ip}"
	nmap_result="$(${nmap_command})"
	open_ports="$(echo \"${nmap_result}\" | grep -Eo '[0-9]{1,5}/tcp' | sed 's@/tcp@\n@g')"
	readarray -t OPEN_PORTS_ARRAY < <(echo "${open_ports}" 2> /dev/null) &>/dev/null

	echo "${nmap_result}" | grep -Eo '[0-9]{1,5}.*$'

	print_yellow "Finished. Discovered: ${OPEN_PORTS_ARRAY[*]}"


}

function perform_tests() {
	for port in "${OPEN_PORTS_ARRAY[@]}"; do
		case "${port}" in
			"21")
				ftp_checks
			;;
			"53")
				dns_checks
			;;
			"80")
			        http_checks "http://${ip}"
			;;
			"443")
                                http_checks "https://${ip}"
			;;
			"445")
				smb_checks
			;;
			"8080")
			        http_checks "http://${ip}:8080"
			;;
			*)
				if [ ! -z "${port}" ];then
					print_error "\nNo tests programmed for ${port} port"
				fi
			;;
		esac


	done

}

function ftp_checks() {
	print_yellow '**** FTP CHECKS'
	print_yellow 'Check: FTP anonymous login'
	command="msfconsole -x \" use auxiliary/scanner/ftp/anonymous; set RHOSTS ${ip}; run; exit\""
	print_yellow "Test: ${command}"
	eval "${command}" | grep "${ip}"

}

###############     PROTOCOL TEST       ###########
function dns_checks() {
	#Use a list of domains. Taken as input if transferzone is possible

	print_yellow '**** DNS CHECKS'
	print_yellow 'Check: Zone transfer'
	for dom in "${possible_domains[@]}"; do
		command="host -l ${dom} ${ip}"
		print_yellow "Test: ${command}"
		eval "${command}"

		#command="dig axfr $1 @${ip}"
		#print_yellow "Test: ${command}"
		#eval "${command}"
	done

	command="dnsrecon -r ${possible_network}/24 -n ${ip}"
	print_yellow "Test: ${command}"
	eval "${command}"

}

function smb_checks() {
	print_yellow '**** SMB CHECKS'
	print_yellow 'Check: SMB shared folders'
	command="msfconsole -x \" use auxiliary/scanner/smb/smb_version; set RHOSTS ${ip}; run; exit\""
	print_yellow "Test: ${command}"
	eval "${command}" | grep "${ip}"

	for user in "${possible_usernames[@]}"; do
		command="smbclient -L ${ip} -U=${user}%test "
		print_yellow "Test: ${command}"
		eval "${command}"
	done

	command="enum4linux ${ip}"
	print_yellow "Test: ${command}"
	eval "${command}"

}

function http_checks() {
	print_yellow '**** HTTP CHECKS'
	print_yellow 'Check: Enumerate web directories'
	command="dirsearch -u $1 -e asp,aspx,html,php,txt,jpg,png,old,bak,zip,json,xml,xls,csv,tsv -f -r"
	print_yellow  "Test: ${command}"
	eval "$command"
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

