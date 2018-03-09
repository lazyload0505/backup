#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 14.04+
#	Description: Install the ShadowsocksR server OneKey
#	Version: 2.0.3
#	Author: Toyo
#	Blog: https://doub.io/ss-jc42/
#=================================================

ssr_folder="/usr/local/shadowsocksr"
ssr_ss_file="${ssr_folder}/shadowsocks"
config_file="${ssr_folder}/config.json"
config_folder="/etc/shadowsocksr"
config_user_file="${config_folder}/user-config.json"
ssr_log_file="${ssr_ss_file}/ssserver.log"
Libsodiumr_file="/usr/local/lib/libsodium.so"
Libsodiumr_ver_backup="1.0.12"
Server_Speeder_file="/serverspeeder/bin/serverSpeeder.sh"
BBR_file="${PWD}/bbr.sh"
jq_file="${ssr_folder}/jq"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[??]${Font_color_suffix}"
Error="${Red_font_prefix}[??]${Font_color_suffix}"
Tip="${Green_font_prefix}[??]${Font_color_suffix}"
Separator_1="??????????????????????????????"

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
check_pid(){
	PID=`ps -ef |grep -v grep | grep server.py |awk '{print $2}'`
}
SSR_installation_status(){
	[[ ! -e ${config_user_file} ]] && echo -e "${Error} ???? ShadowsocksR ???????? !" && exit 1
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} ???? ShadowsocksR ??????? !" && exit 1
}
Server_Speeder_installation_status(){
	[[ ! -e ${Server_Speeder_file} ]] && echo -e "${Error} ???? ??(Server Speeder)???? !" && exit 1
}
BBR_installation_status(){
	if [[ ! -e ${BBR_file} ]]; then
		echo -e "${Error} ???? BBR???????..."
		if ! wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/bbr.sh; then
			echo -e "${Error} BBR ?????? !" && exit 1
		else
			echo -e "${Info} BBR ?????? !"
			chmod +x bbr.sh
		fi
	fi
}
# ?? ?????
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
}
Del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
	else
		iptables-save > /etc/iptables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		chkconfig --level 2345 iptables on
	elif [[ ${release} == "debian" ]]; then
		iptables-save > /etc/iptables.up.rules
		cat > /etc/network/if-pre-up.d/iptables<<-EOF
#!/bin/bash
/sbin/iptables-restore < /etc/iptables.up.rules
EOF
		chmod +x /etc/network/if-pre-up.d/iptables
	elif [[ ${release} == "ubuntu" ]]; then
		iptables-save > /etc/iptables.up.rules
		echo -e "\npre-up iptables-restore < /etc/iptables.up.rules
post-down iptables-save > /etc/iptables.up.rules" >> /etc/network/interfaces
		chmod +x /etc/network/interfaces
	fi
}
# ?? ????
Get_IP(){
	ip=`wget -qO- -t1 -T2 ipinfo.io/ip`
	[[ -z "$ip" ]] && ip="VPS_IP"
}
Get_User(){
	[[ ! -e ${jq_file} ]] && echo -e "${Error} JQ??? ??????? !" && exit 1
	port=`${jq_file} '.server_port' ${config_user_file}`
	password=`${jq_file} '.password' ${config_user_file} | sed 's/^.//;s/.$//'`
	method=`${jq_file} '.method' ${config_user_file} | sed 's/^.//;s/.$//'`
	protocol=`${jq_file} '.protocol' ${config_user_file} | sed 's/^.//;s/.$//'`
	obfs=`${jq_file} '.obfs' ${config_user_file} | sed 's/^.//;s/.$//'`
	protocol_param=`${jq_file} '.protocol_param' ${config_user_file} | sed 's/^.//;s/.$//'`
	speed_limit_per_con=`${jq_file} '.speed_limit_per_con' ${config_user_file}`
	speed_limit_per_user=`${jq_file} '.speed_limit_per_user' ${config_user_file}`
}
ss_link_qr(){
	SSbase64=`echo -n "${method}:${password}@${ip}:${port}" | base64 | sed ':a;N;s/\n/ /g;ta' | sed 's/ //g'`
	SSurl="ss://"${SSbase64}
	SSQRcode="http://doub.pw/qr/qr.php?text="${SSurl}
	ss_link=" SS    ?? : ${Green_font_prefix}${SSurl}${Font_color_suffix} \n SS  ??? : ${Green_font_prefix}${SSQRcode}${Font_color_suffix}"
}
ssr_link_qr(){
	SSRprotocol=`echo ${protocol} | sed 's/_compatible//g'`
	SSRobfs=`echo ${obfs} | sed 's/_compatible//g'`
	SSRPWDbase64=`echo -n "${password}" | base64 | sed ':a;N;s/\n/ /g;ta' | sed 's/ //g'`
	SSRbase64=`echo -n "${ip}:${port}:${SSRprotocol}:${method}:${SSRobfs}:${SSRPWDbase64}" | base64 | sed ':a;N;s/\n/ /g;ta' | sed 's/ //g'`
	SSRurl="ssr://"${SSRbase64}
	SSRQRcode="http://doub.pw/qr/qr.php?text="${SSRurl}
	ssr_link=" SSR   ?? : ${Red_font_prefix}${SSRurl}${Font_color_suffix} \n SSR ??? : ${Red_font_prefix}${SSRQRcode}${Font_color_suffix} \n "
}
ss_ssr_determine(){
	protocol_suffix=`echo ${protocol} | awk -F "_" '{print $NF}'`
	obfs_suffix=`echo ${obfs} | awk -F "_" '{print $NF}'`
	if [[ ${protocol} = "origin" ]]; then
		if [[ ${obfs} = "plain" ]]; then
			ss_link_qr
			ssr_link=""
		else
			if [[ ${obfs_suffix} != "compatible" ]]; then
				ss_link=""
			else
				ss_link_qr
			fi
		fi
	else
		if [[ ${protocol_suffix} != "compatible" ]]; then
			ss_link=""
		else
			if [[ ${obfs_suffix} != "compatible" ]]; then
				if [[ ${obfs_suffix} = "plain" ]]; then
					ss_link_qr
				else
					ss_link=""
				fi
			else
				ss_link_qr
			fi
		fi
	fi
	ssr_link_qr
}
# ?? ????
View_User(){
	SSR_installation_status
	Get_IP
	Get_User
	now_mode=`${jq_file} '.port_password' ${config_user_file}`
	[[ -z ${protocol_param} ]] && protocol_param="0(??)"
	if [[ "${now_mode}" = "null" ]]; then
		ss_ssr_determine
		clear && echo "===================================================" && echo
		echo -e " ShadowsocksR?? ?????" && echo
		echo -e " I  P\t    : ${Green_font_prefix}${ip}${Font_color_suffix}"
		echo -e " ??\t    : ${Green_font_prefix}${port}${Font_color_suffix}"
		echo -e " ??\t    : ${Green_font_prefix}${password}${Font_color_suffix}"
		echo -e " ??\t    : ${Green_font_prefix}${method}${Font_color_suffix}"
		echo -e " ??\t    : ${Red_font_prefix}${protocol}${Font_color_suffix}"
		echo -e " ??\t    : ${Red_font_prefix}${obfs}${Font_color_suffix}"
		echo -e " ????? : ${Green_font_prefix}${protocol_param}${Font_color_suffix}"
		echo -e " ????? : ${Green_font_prefix}${speed_limit_per_con} KB/S${Font_color_suffix}"
		echo -e " ????? : ${Green_font_prefix}${speed_limit_per_user} KB/S${Font_color_suffix}"
		echo -e "${ss_link}"
		echo -e "${ssr_link}"
		echo -e " ${Green_font_prefix} ??: ${Font_color_suffix}
 ?????????????????????????
 ????????[ _compatible ]???? ??????/???"
		echo && echo "==================================================="
	else
		user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
		[[ ${user_total} = "0" ]] && echo -e "${Error} ???? ????????? !" && exit 1
		clear && echo "===================================================" && echo
		echo -e " ShadowsocksR?? ?????" && echo
		echo -e " I  P\t    : ${Green_font_prefix}${ip}${Font_color_suffix}"
		echo -e " ??\t    : ${Green_font_prefix}${method}${Font_color_suffix}"
		echo -e " ??\t    : ${Red_font_prefix}${protocol}${Font_color_suffix}"
		echo -e " ??\t    : ${Red_font_prefix}${obfs}${Font_color_suffix}"
		echo -e " ????? : ${Green_font_prefix}${protocol_param}${Font_color_suffix}"
		echo -e " ????? : ${Green_font_prefix}${speed_limit_per_con} KB/S${Font_color_suffix}"
		echo -e " ????? : ${Green_font_prefix}${speed_limit_per_user} KB/S${Font_color_suffix}" && echo
		for((integer = ${user_total}; integer >= 1; integer--))
		do
			port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
			password=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $2}' | sed -n "${integer}p" | perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
			ss_ssr_determine
			echo -e ${Separator_1}
			echo -e " ??\t    : ${Green_font_prefix}${port}${Font_color_suffix}"
			echo -e " ??\t    : ${Green_font_prefix}${password}${Font_color_suffix}"
			echo -e "${ss_link}"
			echo -e "${ssr_link}"
		done
		echo -e " ${Green_font_prefix} ??: ${Font_color_suffix}
 ?????????????????????????
 ????????[ _compatible ]???? ??????/???"
		echo && echo "==================================================="
	fi
}
# ?? ????
Set_config_port(){
	while true
	do
	echo -e "???????ShadowsocksR?? ??"
	stty erase '^H' && read -p "(??: 2333):" ssr_port
	[[ -z "$ssr_port" ]] && ssr_port="2333"
	expr ${ssr_port} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_port} -ge 1 ]] && [[ ${ssr_port} -le 65535 ]]; then
			echo && echo ${Separator_1} && echo -e "	?? : ${Green_font_prefix}${ssr_port}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ????????(1-65535)"
		fi
	else
		echo -e "${Error} ????????(1-65535)"
	fi
	done
}
Set_config_password(){
	echo "???????ShadowsocksR?? ??"
	stty erase '^H' && read -p "(??: supercell):" ssr_password
	[[ -z "${ssr_password}" ]] && ssr_password="supercell"
	echo && echo ${Separator_1} && echo -e "	?? : ${Green_font_prefix}${ssr_password}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_method(){
	echo -e "???????ShadowsocksR?? ????
 ${Green_font_prefix}1.${Font_color_suffix} rc4-md5
 ${Green_font_prefix}2.${Font_color_suffix} aes-128-ctr
 ${Green_font_prefix}3.${Font_color_suffix} aes-256-ctr
 ${Green_font_prefix}4.${Font_color_suffix} aes-256-cfb
 ${Green_font_prefix}5.${Font_color_suffix} aes-256-cfb8
 ${Green_font_prefix}6.${Font_color_suffix} camellia-256-cfb
 ${Green_font_prefix}7.${Font_color_suffix} chacha20
 ${Green_font_prefix}8.${Font_color_suffix} chacha20-ietf
???chacha20-*??????????????? libsodium ????????ShadowsocksR !" && echo
	stty erase '^H' && read -p "(??: 2. aes-128-ctr):" ssr_method
	[[ -z "${ssr_method}" ]] && ssmethod="2"
	if [[ ${ssr_method} == "1" ]]; then
		ssr_method="rc4-md5"
	elif [[ ${ssr_method} == "2" ]]; then
		ssr_method="aes-128-ctr"
	elif [[ ${ssr_method} == "3" ]]; then
		ssr_method="aes-256-ctr"
	elif [[ ${ssr_method} == "4" ]]; then
		ssr_method="aes-256-cfb"
	elif [[ ${ssr_method} == "5" ]]; then
		ssr_method="aes-256-cfb8"
	elif [[ ${ssr_method} == "6" ]]; then
		ssr_method="camellia-256-cfb"
	elif [[ ${ssr_method} == "7" ]]; then
		ssr_method="chacha20"
	elif [[ ${ssr_method} == "8" ]]; then
		ssr_method="chacha20-ietf"
	else
		ssr_method="aes-128-ctr"
	fi
	echo && echo ${Separator_1} && echo -e "	?? : ${Green_font_prefix}${ssr_method}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_protocol(){
	echo -e "???????ShadowsocksR?? ????
 ${Green_font_prefix}1.${Font_color_suffix} origin
 ${Green_font_prefix}2.${Font_color_suffix} auth_sha1_v4
 ${Green_font_prefix}3.${Font_color_suffix} auth_aes128_md5
 ${Green_font_prefix}4.${Font_color_suffix} auth_aes128_sha1" && echo
	stty erase '^H' && read -p "(??: 2. auth_sha1_v4):" ssr_protocol
	[[ -z "${ssr_protocol}" ]] && ssr_protocol="2"
	if [[ ${ssr_protocol} == "1" ]]; then
		ssr_protocol="origin"
	elif [[ ${ssr_protocol} == "2" ]]; then
		ssr_protocol="auth_sha1_v4"
	elif [[ ${ssr_protocol} == "3" ]]; then
		ssr_protocol="auth_aes128_md5"
	elif [[ ${ssr_protocol} == "4" ]]; then
		ssr_protocol="auth_aes128_sha1"
	else
		ssr_protocol="auth_sha1_v4"
	fi
	echo && echo ${Separator_1} && echo -e "	?? : ${Green_font_prefix}${ssr_protocol}${Font_color_suffix}" && echo ${Separator_1} && echo
	if [[ ${ssr_protocol} != "origin" ]]; then
		if [[ ${ssr_protocol} == "auth_sha1_v4" ]]; then
			stty erase '^H' && read -p "???? ????????(_compatible)?[Y/n]" ssr_protocol_yn
			[[ -z "${ssr_protocol_yn}" ]] && ssr_protocol_yn="y"
			[[ $ssr_protocol_yn == [Yy] ]] && ssr_protocol=${ssr_protocol}"_compatible"
			echo
		fi
	fi
}
Set_config_obfs(){
	echo -e "???????ShadowsocksR?? ????
 ${Green_font_prefix}1.${Font_color_suffix} plain
 ${Green_font_prefix}2.${Font_color_suffix} http_simple
 ${Green_font_prefix}3.${Font_color_suffix} http_post
 ${Green_font_prefix}4.${Font_color_suffix} random_head
 ${Green_font_prefix}5.${Font_color_suffix} tls1.2_ticket_auth" && echo
	stty erase '^H' && read -p "(??: 5. tls1.2_ticket_auth):" ssr_obfs
	[[ -z "${ssr_obfs}" ]] && ssr_obfs="5"
	if [[ ${ssr_obfs} == "1" ]]; then
		ssr_obfs="plain"
	elif [[ ${ssr_obfs} == "2" ]]; then
		ssr_obfs="http_simple"
	elif [[ ${ssr_obfs} == "3" ]]; then
		ssr_obfs="http_post"
	elif [[ ${ssr_obfs} == "4" ]]; then
		ssr_obfs="random_head"
	elif [[ ${ssr_obfs} == "5" ]]; then
		ssr_obfs="tls1.2_ticket_auth"
	else
		ssr_obfs="tls1.2_ticket_auth"
	fi
	echo && echo ${Separator_1} && echo -e "	?? : ${Green_font_prefix}${ssr_obfs}${Font_color_suffix}" && echo ${Separator_1} && echo
	if [[ ${ssr_obfs} != "plain" ]]; then
			stty erase '^H' && read -p "???? ????????(_compatible)?[Y/n]" ssr_obfs_yn
			[[ -z "${ssr_obfs_yn}" ]] && ssr_obfs_yn="y"
			[[ $ssr_obfs_yn == [Yy] ]] && ssr_obfs=${ssr_obfs}"_compatible"
			echo
	fi
}
Set_config_protocol_param(){
	while true
	do
	echo -e "???????ShadowsocksR?? ??????? (${Green_font_prefix} auth_* ???? ???????? ${Font_color_suffix})"
	echo -e "${Tip} ???????????????????????(????????????????)????? 2??"
	stty erase '^H' && read -p "(??: ??):" ssr_protocol_param
	[[ -z "$ssr_protocol_param" ]] && ssr_protocol_param="" && echo && break
	expr ${ssr_protocol_param} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_protocol_param} -ge 1 ]] && [[ ${ssr_protocol_param} -le 9999 ]]; then
			echo && echo ${Separator_1} && echo -e "	????? : ${Green_font_prefix}${ssr_protocol_param}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ????????(1-9999)"
		fi
	else
		echo -e "${Error} ????????(1-9999)"
	fi
	done
}
Set_config_speed_limit_per_con(){
	while true
	do
	echo -e "??????????? ??? ????(???KB/S)"
	echo -e "${Tip} ?????????? ????????????????"
	stty erase '^H' && read -p "(??: ??):" ssr_speed_limit_per_con
	[[ -z "$ssr_speed_limit_per_con" ]] && ssr_speed_limit_per_con=0 && echo && break
	expr ${ssr_speed_limit_per_con} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_speed_limit_per_con} -ge 1 ]] && [[ ${ssr_speed_limit_per_con} -le 131072 ]]; then
			echo && echo ${Separator_1} && echo -e "	????? : ${Green_font_prefix}${ssr_speed_limit_per_con} KB/S${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ????????(1-131072)"
		fi
	else
		echo -e "${Error} ????????(1-131072)"
	fi
	done
}
Set_config_speed_limit_per_user(){
	while true
	do
	echo
	echo -e "??????????? ??? ????(???KB/S)"
	echo -e "${Tip} ?????????? ??? ??????????????"
	stty erase '^H' && read -p "(??: ??):" ssr_speed_limit_per_user
	[[ -z "$ssr_speed_limit_per_user" ]] && ssr_speed_limit_per_user=0 && echo && break
	expr ${ssr_speed_limit_per_user} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_speed_limit_per_user} -ge 1 ]] && [[ ${ssr_speed_limit_per_user} -le 131072 ]]; then
			echo && echo ${Separator_1} && echo -e "	????? : ${Green_font_prefix}${ssr_speed_limit_per_user} KB/S${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ????????(1-131072)"
		fi
	else
		echo -e "${Error} ????????(1-131072)"
	fi
	done
}
Set_config_all(){
	Set_config_port
	Set_config_password
	Set_config_method
	Set_config_protocol
	Set_config_obfs
	Set_config_protocol_param
	Set_config_speed_limit_per_con
	Set_config_speed_limit_per_user
}
# ?? ????
Modify_config_port(){
	sed -i 's/"server_port": '"$(echo ${port})"'/"server_port": '"$(echo ${ssr_port})"'/g' ${config_user_file}
}
Modify_config_password(){
	sed -i 's/"password": "'"$(echo ${password})"'"/"password": "'"$(echo ${ssr_password})"'"/g' ${config_user_file}
}
Modify_config_method(){
	sed -i 's/"method": "'"$(echo ${method})"'"/"method": "'"$(echo ${ssr_method})"'"/g' ${config_user_file}
}
Modify_config_protocol(){
	sed -i 's/"protocol": "'"$(echo ${protocol})"'"/"protocol": "'"$(echo ${ssr_protocol})"'"/g' ${config_user_file}
}
Modify_config_obfs(){
	sed -i 's/"obfs": "'"$(echo ${obfs})"'"/"obfs": "'"$(echo ${ssr_obfs})"'"/g' ${config_user_file}
}
Modify_config_protocol_param(){
	sed -i 's/"protocol_param": "'"$(echo ${protocol_param})"'"/"protocol_param": "'"$(echo ${ssr_protocol_param})"'"/g' ${config_user_file}
}
Modify_config_speed_limit_per_con(){
	sed -i 's/"speed_limit_per_con": '"$(echo ${speed_limit_per_con})"'/"speed_limit_per_con": '"$(echo ${ssr_speed_limit_per_con})"'/g' ${config_user_file}
}
Modify_config_speed_limit_per_user(){
	sed -i 's/"speed_limit_per_user": '"$(echo ${speed_limit_per_user})"'/"speed_limit_per_user": '"$(echo ${ssr_speed_limit_per_user})"'/g' ${config_user_file}
}
Modify_config_all(){
	Modify_config_port
	Modify_config_password
	Modify_config_method
	Modify_config_protocol
	Modify_config_obfs
	Modify_config_protocol_param
	Modify_config_speed_limit_per_con
	Modify_config_speed_limit_per_user
}
Modify_config_port_many(){
	sed -i 's/"'"$(echo ${port})"'":/"'"$(echo ${ssr_port})"'":/g' ${config_user_file}
}
Modify_config_password_many(){
	sed -i 's/"'"$(echo ${password})"'"/"'"$(echo ${ssr_password})"'"/g' ${config_user_file}
}
# ?? ????
Write_configuration(){
	cat > ${config_user_file}<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "server_port": ${ssr_port},
    "local_address": "127.0.0.1",
    "local_port": 1080,

    "password": "${ssr_password}",
    "method": "${ssr_method}",
    "protocol": "${ssr_protocol}",
    "protocol_param": "${ssr_protocol_param}",
    "obfs": "${ssr_obfs}",
    "obfs_param": "",
    "speed_limit_per_con": ${ssr_speed_limit_per_con},
    "speed_limit_per_user": ${ssr_speed_limit_per_user},

    "additional_ports" : {},
    "timeout": 120,
    "udp_timeout": 60,
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false
}
EOF
}
Write_configuration_many(){
	cat > ${config_user_file}<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "local_address": "127.0.0.1",
    "local_port": 1080,

    "port_password":{
        "${ssr_port}":"${ssr_password}"
    },
    "method": "${ssr_method}",
    "protocol": "${ssr_protocol}",
    "protocol_param": "${ssr_protocol_param}",
    "obfs": "${ssr_obfs}",
    "obfs_param": "",
    "speed_limit_per_con": ${ssr_speed_limit_per_con},
    "speed_limit_per_user": ${ssr_speed_limit_per_user},

    "additional_ports" : {},
    "timeout": 120,
    "udp_timeout": 60,
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false
}
EOF
}
Check_python(){
	python_ver=`python -h`
	if [[ -z ${python_ver} ]]; then
		echo -e "${Info} ????Python?????..."
		if [[ ${release} == "centos" ]]; then
			yum install -y python
		else
			apt-get install -y python
		fi
	fi
}
Centos_yum(){
	yum update
	yum install -y vim git
}
Debian_apt(){
	apt-get update
	apt-get install -y vim git
}
# ?? ShadowsocksRShadowsocksR
Download_SSR(){
	cd "/usr/local"
	#git config --global http.sslVerify false
	env GIT_SSL_NO_VERIFY=true git clone -b manyuser https://github.com/shadowsocksr-backup/shadowsocksr.git
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR??? ???? !" && exit 1
	[[ -e ${config_folder} ]] && rm -rf ${config_folder}
	mkdir ${config_folder}
	[[ ! -e ${config_folder} ]] && echo -e "${Error} ShadowsocksR???????? ???? !" && exit 1
	echo -e "${Info} ShadowsocksR??? ???? !"
}
Service_SSR(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/ssr_centos -O /etc/init.d/ssr; then
			echo -e "${Error} ShadowsocksR?? ???????? !" && exit 1
		fi
		chmod +x /etc/init.d/ssr
		chkconfig --add ssr
		chkconfig ssr on
	else
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/ssr_debian -O /etc/init.d/ssr; then
			echo -e "${Error} ShadowsocksR?? ???????? !" && exit 1
		fi
		chmod +x /etc/init.d/ssr
		update-rc.d -f ssr defaults
	fi
	echo -e "${Info} ShadowsocksR?? ???????? !"
}
# ?? JQ???
JQ_install(){
	if [[ ! -e ${jq_file} ]]; then
		if [[ ${bit} = "x86_64" ]]; then
			wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" -O ${jq_file}
		else
			wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux32" -O ${jq_file}
		fi
		[[ ! -e ${jq_file} ]] && echo -e "${Error} JQ??? ???????? !" && exit 1
		chmod +x ${jq_file}
		echo -e "${Info} JQ??? ???????..." 
	else
		echo -e "${Info} JQ??? ??????..."
	fi
}
# ?? ??
Installation_dependency(){
	if [[ ${release} == "centos" ]]; then
		Centos_yum
	else
		Debian_apt
	fi
	Check_python
	echo "nameserver 8.8.8.8" > /etc/resolv.conf
	echo "nameserver 8.8.4.4" >> /etc/resolv.conf
	cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}
Install_SSR(){
	[[ -e ${config_user_file} ]] && echo -e "${Error} ShadowsocksR ???????????( ????????????????? ) !" && exit 1
	[[ -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR ??????????( ????????????????? ) !" && exit 1
	echo -e "${Info} ???? ShadowsocksR????..."
	Set_config_all
	echo -e "${Info} ????/?? ShadowsocksR??..."
	Installation_dependency
	echo -e "${Info} ????/?? ShadowsocksR??..."
	Download_SSR
	echo -e "${Info} ????/?? ShadowsocksR????(init)..."
	Service_SSR
	echo -e "${Info} ????/?? JSNO??? JQ..."
	JQ_install
	echo -e "${Info} ???? ShadowsocksR????..."
	Write_configuration
	echo -e "${Info} ???? iptables???..."
	Set_iptables
	echo -e "${Info} ???? iptables?????..."
	Add_iptables
	echo -e "${Info} ???? iptables?????..."
	Save_iptables
	echo -e "${Info} ???? ????????? ShadowsocksR???..."
	Start_SSR
}
Update_SSR(){
	SSR_installation_status
	cd ${ssr_folder}
	git pull
	Restart_SSR
}
Uninstall_SSR(){
	[[ ! -e ${config_user_file} ]] && [[ ! -e ${ssr_folder} ]] && echo -e "${Error} ???? ShadowsocksR???? !" && exit 1
	echo "??? ??ShadowsocksR?[y/N]" && echo
	stty erase '^H' && read -p "(??: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z "${PID}" ]] && kill -9 ${PID}
		if [[ "${now_mode}" = "null" ]]; then
			port=`${jq_file} '.server_port' ${config_user_file}`
			Del_iptables
		else
			user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
			for((integer = 1; integer <= ${user_total}; integer++))
			do
				port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
				Del_iptables
			done
		fi
		if [[ ${release} = "centos" ]]; then
			chkconfig --del ssr
		else
			update-rc.d -f ssr remove
		fi
		rm -rf ${ssr_folder} && rm -rf ${config_folder} && rm -rf /etc/init.d/ssr
		echo && echo " ShadowsocksR ???? !" && echo
	else
		echo && echo " ?????..." && echo
	fi
}
Check_Libsodium_ver(){
	echo -e "${Info} ???? libsodium ????..."
	Libsodiumr_ver=`wget -qO- https://github.com/jedisct1/libsodium/releases/latest | grep "<title>" | perl -e 'while($_=<>){ /Release (.*) · jedisct1/; print $1;}'`
	[[ -z ${Libsodiumr_ver} ]] && Libsodiumr_ver=${Libsodiumr_ver_backup}
	echo -e "${Info} libsodium ????? ${Green_font_prefix}${Libsodiumr_ver}${Font_color_suffix} !"
}
Install_Libsodium(){
	[[ -e ${Libsodiumr_file} ]] && echo -e "${Error} libsodium ??? !" && exit 1
	echo -e "${Info} libsodium ????????..."
	Check_Libsodium_ver
	if [[ ${release} == "centos" ]]; then
		yum update
		yum -y groupinstall "Development Tools"
		wget  --no-check-certificate -N https://github.com/jedisct1/libsodium/releases/download/${Libsodiumr_ver}/libsodium-${Libsodiumr_ver}.tar.gz
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		./configure --disable-maintainer-mode && make -j2 && make install
		echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	else
		apt-get update
		apt-get install -y build-essential
		wget  --no-check-certificate -N https://github.com/jedisct1/libsodium/releases/download/${Libsodiumr_ver}/libsodium-${Libsodiumr_ver}.tar.gz
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		./configure --disable-maintainer-mode && make -j2 && make install
	fi
	ldconfig
	cd .. && rm -rf libsodium-${Libsodiumr_ver}.tar.gz && rm -rf libsodium-${Libsodiumr_ver}
	[[ ! -e ${Libsodiumr_file} ]] && echo -e "${Error} libsodium ???? !" && exit 1
	echo && echo -e "${Info} libsodium ???? !" && echo
}
# ?? ????
debian_View_user_connection_info(){
	if [[ "${now_mode}" = "null" ]]; then
		now_mode="???" && user_total="1"
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |wc -l`
		user_port=`${jq_file} '.server_port' ${config_user_file}`
		user_IP=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep "${user_port}" |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u`
		user_IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep "${user_port}" |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |wc -l`
		user_list_all="??: ${Green_font_prefix}"${user_port}"${Font_color_suffix}, ??IP??: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}, ????IP: ${Green_font_prefix}"${user_IP}"${Font_color_suffix}\n"
		echo -e "????: ${Green_font_prefix} "${now_mode}" ${Font_color_suffix}"
		echo -e ${user_list_all}
	else
		now_mode="${Word_multi_port}" && user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |wc -l`
		user_list_all=""
		for((integer = ${user_total}; integer >= 1; integer--))
		do
			user_port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
			user_IP=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep "${user_port}" |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u`
			user_IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep "${user_port}" |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |wc -l`
			user_list_all=${user_list_all}"??: ${Green_font_prefix}"${user_port}"${Font_color_suffix}, ??IP??: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}, ????IP: ${Green_font_prefix}"${user_IP}"${Font_color_suffix}\n"
		done
		echo -e "????: ${Green_font_prefix} "${now_mode}" ${Font_color_suffix} ?????: ${Green_font_prefix} "${user_total}" ${Font_color_suffix} ???IP??: ${Green_font_prefix} "${IP_total}" ${Font_color_suffix} "
		echo -e ${user_list_all}
	fi
}
centos_View_user_connection_info(){
	if [[ "${now_mode}" = "null" ]]; then
		now_mode="???" && user_total="1"
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' | grep '::ffff:' |awk '{print $4}' |sort -u |wc -l`
		user_port=`${jq_file} '.server_port' ${config_user_file}`
		user_IP=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep "${user_port}" | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u`
		user_IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep "${user_port}" | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |wc -l`
		user_list_all="??: ${Green_font_prefix}"${user_port}"${Font_color_suffix}, ??IP??: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}, ????IP: ${Green_font_prefix}"${user_IP}"${Font_color_suffix}\n"
		echo -e "????: ${Green_font_prefix} "${now_mode}" ${Font_color_suffix}"
		echo -e ${user_list_all}
	else
		now_mode="???" && user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' | grep '::ffff:' |awk '{print $4}' |sort -u |wc -l`
		user_list_all=""
		user_id=0
		for((integer = 1; integer <= ${user_total}; integer++))
		do
			user_port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
			user_IP=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep "${user_port}" | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u`
			user_IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep "${user_port}" | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |wc -l`
			user_id=$[$user_id+1]
			user_list_all=${user_list_all}"??: ${Green_font_prefix}"${user_port}"${Font_color_suffix}, ??IP??: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}, ????IP: ${Green_font_prefix}"${user_IP}"${Font_color_suffix}\n"
		done
		echo -e "????: ${Green_font_prefix} "${now_mode}" ${Font_color_suffix} ?????: ${Green_font_prefix} "${user_total}" ${Font_color_suffix} ???IP??: ${Green_font_prefix} "${IP_total}" ${Font_color_suffix} "
		echo -e ${user_list_all}
	fi
}
View_user_connection_info(){
	SSR_installation_status
	if [[ ${release} = "centos" ]]; then
		centos_View_user_connection_info
	else
		debian_View_user_connection_info
	fi
}
# ?? ????
Modify_Config(){
	SSR_installation_status
	if [[ "${now_mode}" = "null" ]]; then
		echo && echo -e "????: ??????????
 ${Green_font_prefix}1.${Font_color_suffix} ?? ????
 ${Green_font_prefix}2.${Font_color_suffix} ?? ????
 ${Green_font_prefix}3.${Font_color_suffix} ?? ????
 ${Green_font_prefix}4.${Font_color_suffix} ?? ????
 ${Green_font_prefix}5.${Font_color_suffix} ?? ????
 ${Green_font_prefix}6.${Font_color_suffix} ?? ?????
 ${Green_font_prefix}7.${Font_color_suffix} ?? ?????
 ${Green_font_prefix}8.${Font_color_suffix} ?? ?????
 ${Green_font_prefix}9.${Font_color_suffix} ?? ????" && echo
		stty erase '^H' && read -p "(??: ??):" ssr_modify
		[[ -z "${ssr_modify}" ]] && echo "???..." && exit 1
		Get_User
		if [[ ${ssr_modify} == "1" ]]; then
			Set_config_port
			Modify_config_port
			Add_iptables
			Del_iptables
			Save_iptables
		elif [[ ${ssr_modify} == "2" ]]; then
			Set_config_password
			Modify_config_password
		elif [[ ${ssr_modify} == "3" ]]; then
			Set_config_method
			Modify_config_method
		elif [[ ${ssr_modify} == "4" ]]; then
			Set_config_protocol
			Modify_config_protocol
		elif [[ ${ssr_modify} == "5" ]]; then
			Set_config_obfs
			Modify_config_obfs
		elif [[ ${ssr_modify} == "6" ]]; then
			Set_config_protocol_param
			Modify_config_protocol_param
		elif [[ ${ssr_modify} == "7" ]]; then
			Set_config_speed_limit_per_con
			Modify_config_speed_limit_per_con
		elif [[ ${ssr_modify} == "8" ]]; then
			Set_config_speed_limit_per_user
			Modify_config_speed_limit_per_user
		elif [[ ${ssr_modify} == "9" ]]; then
			Set_config_all
			Modify_config_all
		else
			echo -e "${Error} ????????(1-9)" && exit 1
		fi
	else
		echo && echo -e "????: ??????????
 ${Green_font_prefix}1.${Font_color_suffix} ?? ????
 ${Green_font_prefix}2.${Font_color_suffix} ?? ????
 ${Green_font_prefix}3.${Font_color_suffix} ?? ????
??????????
 ${Green_font_prefix}4.${Font_color_suffix} ?? ????
 ${Green_font_prefix}5.${Font_color_suffix} ?? ????
 ${Green_font_prefix}6.${Font_color_suffix} ?? ????
 ${Green_font_prefix}7.${Font_color_suffix} ?? ?????
 ${Green_font_prefix}8.${Font_color_suffix} ?? ?????
 ${Green_font_prefix}9.${Font_color_suffix} ?? ?????
${Green_font_prefix}10.${Font_color_suffix} ?? ????" && echo
		stty erase '^H' && read -p "(??: ??):" ssr_modify
		[[ -z "${ssr_modify}" ]] && echo "???..." && exit 1
		Get_User
		if [[ ${ssr_modify} == "1" ]]; then
			Add_multi_port_user
		elif [[ ${ssr_modify} == "2" ]]; then
			Del_multi_port_user
		elif [[ ${ssr_modify} == "3" ]]; then
			Modify_multi_port_user
		elif [[ ${ssr_modify} == "4" ]]; then
			Set_config_method
			Modify_config_method
		elif [[ ${ssr_modify} == "5" ]]; then
			Set_config_protocol
			Modify_config_protocol
		elif [[ ${ssr_modify} == "6" ]]; then
			Set_config_obfs
			Modify_config_obfs
		elif [[ ${ssr_modify} == "7" ]]; then
			Set_config_protocol_param
			Modify_config_protocol_param
		elif [[ ${ssr_modify} == "8" ]]; then
			Set_config_speed_limit_per_con
			Modify_config_speed_limit_per_con
		elif [[ ${ssr_modify} == "9" ]]; then
			Set_config_speed_limit_per_user
			Modify_config_speed_limit_per_user
		elif [[ ${ssr_modify} == "10" ]]; then
			Set_config_method
			Set_config_protocol
			Set_config_obfs
			Set_config_protocol_param
			Set_config_speed_limit_per_con
			Set_config_speed_limit_per_user
			Modify_config_method
			Modify_config_protocol
			Modify_config_obfs
			Modify_config_protocol_param
			Modify_config_speed_limit_per_con
			Modify_config_speed_limit_per_user
		else
			echo -e "${Error} ????????(1-9)" && exit 1
		fi
	fi
	Restart_SSR
}
# ?? ???????
List_multi_port_user(){
	user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
	[[ ${user_total} = "0" ]] && echo -e "${Error} ???? ????????? !" && exit 1
	user_list_all=""
	for((integer = ${user_total}; integer >= 1; integer--))
	do
		user_port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
		user_password=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $2}' | sed -n "${integer}p" | perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
		user_list_all=${user_list_all}"??: "${user_port}" ??: "${user_password}"\n"
	done
	echo && echo -e "???? ${Green_font_prefix}"${user_total}"${Font_color_suffix}"
	echo -e ${user_list_all}
}
# ?? ???????
Add_multi_port_user(){
	Set_config_port
	Set_config_password
	sed -i "8 i \"        \"${ssr_port}\":\"${ssr_password}\"," ${config_user_file}
	sed -i "8s/^\"//" ${config_user_file}
	Add_iptables
	Save_iptables
	echo -e "${Info} ????????? ${Green_font_prefix}[??: ${ssr_port} , ??: ${ssr_password}]${Font_color_suffix} "
}
# ?? ???????
Modify_multi_port_user(){
	List_multi_port_user
	echo && echo -e "???????????"
	stty erase '^H' && read -p "(??: ??):" modify_user_port
	[[ -z "${modify_user_port}" ]] && echo -e "???..." && exit 1
	del_user=`cat ${config_user_file}|grep "${modify_user_port}"`
	if [ ! -z ${del_user} ]; then
		port=${modify_user_port}
		password=`echo -e ${del_user}|awk -F ":" '{print $NF}'|perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
		Set_config_port
		Set_config_password
		sed -i 's/"'$(echo ${port})'":"'$(echo ${password})'"/"'$(echo ${ssr_port})'":"'$(echo ${ssr_password})'"/g' ${config_user_file}
		Del_iptables
		Add_iptables
		Save_iptables
		echo -e "${Inof} ????????? ${Green_font_prefix}[?: ${modify_user_port}  ${password} , ?: ${ssr_port}  ${ssr_password}]${Font_color_suffix} "
	else
		echo "${Error} ???????? !" && exit 1
	fi
}
# ?? ???????
Del_multi_port_user(){
	List_multi_port_user
	user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
	[[ "${user_total}" = "1" ]] && echo -e "${Error} ??????? 1?????? !" && exit 1
	echo -e "???????????"
	stty erase '^H' && read -p "(??: ??):" del_user_port
	[[ -z "${del_user_port}" ]] && echo -e "???..." && exit 1
	del_user=`cat ${config_user_file}|grep "${del_user_port}"`
	if [[ ! -z ${del_user} ]]; then
		port=${del_user_port}
		Del_iptables
		Save_iptables
		del_user_determine=`echo ${del_user:((${#del_user} - 1))}`
		if [[ ${del_user_determine} != "," ]]; then
			del_user_num=$(sed -n -e "/${port}/=" ${config_user_file})
			del_user_num=$[ $del_user_num - 1 ]
			sed -i "${del_user_num}s/,//g" ${config_user_file}
		fi
		sed -i "/${port}/d" ${config_user_file}
		echo -e "${Info} ????????? ${Green_font_prefix} ${del_user_port} ${Font_color_suffix} "
	else
		echo "${Error} ???????? !" && exit 1
	fi
}
# ???? ????
Manually_Modify_Config(){
	SSR_installation_status
	port=`${jq_file} '.server_port' ${config_user_file}`
	vi ${config_user_file}
	if [[ "${now_mode}" = "null" ]]; then
		ssr_port=`${jq_file} '.server_port' ${config_user_file}`
		Del_iptables
		Add_iptables
	fi
	Restart_SSR
}
# ??????
Port_mode_switching(){
	SSR_installation_status
	if [[ "${now_mode}" = "null" ]]; then
		echo && echo -e "	????: ${Green_font_prefix}???${Font_color_suffix}" && echo
		echo -e "?????? ??????[y/N]"
		stty erase '^H' && read -p "(??: n):" mode_yn
		[[ -z ${mode_yn} ]] && mode_yn="n"
		if [[ ${mode_yn} == [Yy] ]]; then
			port=`${jq_file} '.server_port' ${config_user_file}`
			Set_config_all
			Write_configuration_many
			Del_iptables
			Add_iptables
			Save_iptables
			Restart_SSR
		else
			echo && echo "	???..." && echo
		fi
	else
		echo && echo -e "	????: ${Green_font_prefix}???${Font_color_suffix}" && echo
		echo -e "?????? ??????[y/N]"
		stty erase '^H' && read -p "(??: n):" mode_yn
		[[ -z ${mode_yn} ]] && mode_yn="n"
		if [[ ${mode_yn} == [Yy] ]]; then
			user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
			for((integer = 1; integer <= ${user_total}; integer++))
			do
				port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}'`
				Del_iptables
			done
			Set_config_all
			Write_configuration
			Add_iptables
			Restart_SSR
		else
			echo && echo "	???..." && echo
		fi
	fi
}
Start_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ShadowsocksR ???? !" && exit 1
	service ssr start
	View_User
}
Stop_SSR(){
	SSR_installation_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} ShadowsocksR ??? !" && exit 1
	service ssr stop
}
Restart_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && service ssr stop
	service ssr start
	View_User
}
View_Log(){
	SSR_installation_status
	[[ ! -e ${ssr_log_file} ]] && echo -e "${Error} ShadowsocksR??????? !" && exit 1
	echo && echo -e "${Tip} ? ${Red_font_prefix}Ctrl+C${Font_color_suffix} ??????" && echo
	tail -f ${ssr_log_file}
}
# ??
Configure_Server_Speeder(){
	echo && echo -e "??????
 ${Green_font_prefix}1.${Font_color_suffix} ?? ??
 ${Green_font_prefix}2.${Font_color_suffix} ?? ??
????????
 ${Green_font_prefix}3.${Font_color_suffix} ?? ??
 ${Green_font_prefix}4.${Font_color_suffix} ?? ??
 ${Green_font_prefix}5.${Font_color_suffix} ?? ??
 ${Green_font_prefix}6.${Font_color_suffix} ?? ?? ??" && echo
	stty erase '^H' && read -p "(??: ??):" server_speeder_num
	[[ -z "${server_speeder_num}" ]] && echo "???..." && exit 1
	if [[ ${server_speeder_num} == "1" ]]; then
		Install_ServerSpeeder
	elif [[ ${server_speeder_num} == "2" ]]; then
		Server_Speeder_installation_status
		Uninstall_ServerSpeeder
	elif [[ ${server_speeder_num} == "3" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} start
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "4" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} stop
	elif [[ ${server_speeder_num} == "5" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} restart
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "6" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} status
	else
		echo -e "${Error} ????????(1-6)" && exit 1
	fi
}
Install_ServerSpeeder(){
	[[ -e ${Server_Speeder_file} ]] && echo -e "${Error} ??(Server Speeder) ??? !" && exit 1
	cd /root
	#??91yun.rog??????
	wget -N --no-check-certificate https://raw.githubusercontent.com/91yun/serverspeeder/master/serverspeeder-all.sh
	[[ ! -e "serverspeeder-all.sh" ]] && echo -e "${Error} ?????????? !" && exit 1
	bash serverspeeder-all.sh
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "serverspeeder" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		rm -rf /root/serverspeeder-all.sh
		rm -rf /root/91yunserverspeeder
		rm -rf /root/91yunserverspeeder.tar.gz
		echo -e "${Info} ??(Server Speeder) ???? !" && exit 1
	else
		echo -e "${Error} ??(Server Speeder) ???? !" && exit 1
	fi
}
Uninstall_ServerSpeeder(){
	echo "????? ??(Server Speeder)?[y/N]" && echo
	stty erase '^H' && read -p "(??: n):" unyn
	[[ -z ${unyn} ]] && echo && echo "???..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		chattr -i /serverspeeder/etc/apx*
		/serverspeeder/bin/serverSpeeder.sh uninstall -f
		echo && echo "??(Server Speeder) ???? !" && echo
	fi
}
# BBR
Configure_BBR(){
	echo && echo -e "??????
 ${Green_font_prefix}1.${Font_color_suffix} ?? BBR
????????
 ${Green_font_prefix}2.${Font_color_suffix} ?? BBR
 ${Green_font_prefix}3.${Font_color_suffix} ?? BBR
 ${Green_font_prefix}4.${Font_color_suffix} ?? BBR ??" && echo
echo -e "${Green_font_prefix} [??? ???] ${Font_color_suffix}
1. ????BBR?????????????????(???????)
2. ?????? Debian / Ubuntu ???????OpenVZ??? ???????
3. Debian ?????????? [ ???????? ] ???? ${Green_font_prefix} NO ${Font_color_suffix}
4. ??BBR???????????????? ??BBR" && echo
	stty erase '^H' && read -p "(??: ??):" bbr_num
	[[ -z "${bbr_num}" ]] && echo "???..." && exit 1
	if [[ ${bbr_num} == "1" ]]; then
		Install_BBR
	elif [[ ${bbr_num} == "2" ]]; then
		Start_BBR
	elif [[ ${bbr_num} == "3" ]]; then
		Stop_BBR
	elif [[ ${bbr_num} == "4" ]]; then
		Status_BBR
	else
		echo -e "${Error} ????????(1-4)" && exit 1
	fi
}
Install_BBR(){
	[[ ${release} = "centos" ]] && echo -e "${Error} ?????? CentOS???? BBR !" && exit 1
	BBR_installation_status
	bash bbr.sh
}
Start_BBR(){
	BBR_installation_status
	bash bbr.sh start
}
Stop_BBR(){
	BBR_installation_status
	bash bbr.sh stop
}
Status_BBR(){
	BBR_installation_status
	bash bbr.sh status
}
# ????
Other_functions(){
	echo && echo -e "??????
  ${Green_font_prefix}1.${Font_color_suffix} ???iptables ?? BT/PT/SPAM" && echo
	stty erase '^H' && read -p "(??: ??):" other_num
	[[ -z "${other_num}" ]] && echo "???..." && exit 1
	if [[ ${other_num} == "1" ]]; then
		BanBTPTSPAM
	else
		echo -e "${Error} ????????(1-1)" && exit 1
	fi
}
# ?? BT PT SPAM
BanBTPTSPAM(){
	wget -4qO- raw.githubusercontent.com/ToyoDAdoubi/doubi/master/Get_Out_Spam.sh | bash
	Save_iptables
	iptables -L -n
}
# ?? ????
menu_status(){
	if [[ -e ${config_user_file} ]]; then
		check_pid
		if [[ ! -z "${PID}" ]]; then
			echo -e " ????: ${Green_font_prefix}???${Font_color_suffix} ? ${Green_font_prefix}???${Font_color_suffix}"
		else
			echo -e " ????: ${Green_font_prefix}???${Font_color_suffix} ? ${Red_font_prefix}???${Font_color_suffix}"
		fi
		now_mode=`${jq_file} '.port_password' ${config_user_file}`
		if [[ "${now_mode}" = "null" ]]; then
			echo -e " ????: ${Green_font_prefix}???${Font_color_suffix}"
		else
			echo -e " ????: ${Green_font_prefix}???${Font_color_suffix}"
		fi
	else
		echo -e " ????: ${Red_font_prefix}???${Font_color_suffix}"
	fi
}
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} ?????????? ${release} !" && exit 1
echo -e "  ??????????????

  ${Green_font_prefix}1.${Font_color_suffix} ?? ShadowsocksR
  ${Green_font_prefix}2.${Font_color_suffix} ?? ShadowsocksR
  ${Green_font_prefix}3.${Font_color_suffix} ?? ShadowsocksR
  ${Green_font_prefix}4.${Font_color_suffix} ?? libsodium(chacha20)
????????????
  ${Green_font_prefix}5.${Font_color_suffix} ?? ????
  ${Green_font_prefix}6.${Font_color_suffix} ?? ????
  ${Green_font_prefix}7.${Font_color_suffix} ?? ????
  ${Green_font_prefix}8.${Font_color_suffix} ?? ????
  ${Green_font_prefix}9.${Font_color_suffix} ?? ????
????????????
 ${Green_font_prefix}10.${Font_color_suffix} ?? ShadowsocksR
 ${Green_font_prefix}11.${Font_color_suffix} ?? ShadowsocksR
 ${Green_font_prefix}12.${Font_color_suffix} ?? ShadowsocksR
 ${Green_font_prefix}13.${Font_color_suffix} ?? ShadowsocksR ??
????????????
 ${Green_font_prefix}14.${Font_color_suffix} ?? ??
 ${Green_font_prefix}15.${Font_color_suffix} ?? BBR
????????????
 ${Green_font_prefix}16.${Font_color_suffix} ????
 
 ????? ??/BBR ??? OpenVZ
 "
menu_status
echo && stty erase '^H' && read -p "?????(1-16)?" num
case "$num" in
	1)
	Install_SSR
	;;
	2)
	Update_SSR
	;;
	3)
	Uninstall_SSR
	;;
	4)
	Install_Libsodium
	;;
	5)
	View_User
	;;
	6)
	View_user_connection_info
	;;
	7)
	Modify_Config
	;;
	8)
	Manually_Modify_Config
	;;
	9)
	Port_mode_switching
	;;
	10)
	Start_SSR
	;;
	11)
	Stop_SSR
	;;
	12)
	Restart_SSR
	;;
	13)
	View_Log
	;;
	14)
	Configure_Server_Speeder
	;;
	15)
	Configure_BBR
	;;
	16)
	Other_functions
	;;
	*)
	echo -e "${Error} ????????(1-16)"
	;;
esac
