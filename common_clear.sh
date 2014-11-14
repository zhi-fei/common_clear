#!/bin/bash

########################################################################
#程序名：common_clear.sh
# 作者：曹海涛
# 生成日期：2014-08-29
# 功能：通用文件清除脚本，可对多个指定目录按照磁盘空间、
#       文件保存天数进行清理，并可设置目录扫描深度
# 参数：无
# 修改历史：
# 1、作者：曹海涛
#    日期：2014-09-01
#修改内容：
#		   将配置信息独立为单独的配置文件common_clear.conf,并加入配置文件解析函数ImportConf
#          加入定时任务自动配置函数DeployCron
# 2、作者：曹海涛
#    日期：2014-09-02
#修改内容：
#		   将日志文件分为三种类型
#          导入配置文件时检查各配置项是否配置正确
#          优化告警信息
#          增加Exit函数，在退出时清理过期日志
#          本版本只对YYYYMMDD的目录进行扫描
########################################################################


########################################################################
#函数在此定义
########################################################################
########################################################################
# 函 数 名  : InitEnv
# 功能描述  : 初始化脚本
# 输入参数  : 无
# 返 回 值  : 无
# 调用函数  : 无
# 修改历史      :
#  1.日    期   : 2014年08月29日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
########################################################################
function InitEnv
{
	unalias -a

	#版本号	
	VERSION="V1.3_20140902"
	#暂定的正则表达式
	REG_EXP="(^20[0-9]{6}$)|(^20[0-9]{4}$)"
	#当前时间，UTC时间
	DATE_NOW=$(date +'%s')
	#当前日期
	DATE_DAY=$(date +'%Y%m%d')
	#主脚本目录绝对路径
	DIR_INSTALL="$(cd $(dirname $0);pwd)"
	#脚本名，去.sh后缀
	SCRIPT_NAME="$(basename $0 .sh)"
	#配置文件路径
	FILE_CONF="${DIR_INSTALL}/${SCRIPT_NAME}.conf"
	#日志文件目录
	DIR_LOG="${DIR_INSTALL}/logs"
	#脚本运行信息日志
	FILE_RUNINFO="${DIR_LOG}/runinfo_${DATE_DAY}.log"
	#删除文件正常日志
	FILE_LOG_NORMAL="${DIR_LOG}/clear_normal_${DATE_DAY}.log"
	#删除文件异常日志
	FILE_LOG_ERROR="${DIR_LOG}/clear_error_${DATE_DAY}.log"
	#日志保存天数
	LOG_KEEP_DAY=30

	mkdir -p "${DIR_LOG}"
}
########################################################################

########################################################################
# 函 数 名  : Echo
# 功能描述  : 将传入的日志信息附上时间
# 输入参数  : 日志信息
# 返 回 值  : 时间|日志信息
# 调用函数  : 无
# 修改历史      :
#  1.日    期   : 2014年08月29日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
########################################################################
function Echo
{
	local msg="$1"
	local date=$(date +'%Y-%m-%d %H:%M:%S')
	echo "${date}|${msg}"
}
########################################################################

########################################################################
# 函 数 名  : Exit
# 功能描述  : 在退出脚本时清理日志
# 输入参数  : 无
# 返 回 值  : 无
# 调用函数  : Echo
# 修改历史      :
#  1.日    期   : 2014年09月02日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
########################################################################
function Exit
{
	local day_del=$(date -d "- ${LOG_KEEP_DAY} day" +'%Y%m%d')
	for file in runinfo clear_normal clear_error
	do
		local log="${DIR_LOG}/${file}_${day_del}.log"
		if [[ -f ${log} ]];then
			rm -f "${log}"
			Echo "delete log ${log}" >> ${FILE_RUNINFO}
		fi
	done
	
	exit 0
}
########################################################################

########################################################################
# 函 数 名  : ImportConf
# 功能描述  : 导入配置文件,当配置文件不存在时退出脚本并写错误日志
# 输入参数  : 无
# 返 回 值  : 无
# 调用函数  : 无
# 修改历史      :
#  1.日    期   : 2014年09月01日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
#  2.日    期   : 2014年09月02日
#    作    者   : 曹海涛
#    修改内容   : 对配置文件的配置项进行检查，当配置项错误时写日志并退出脚本
########################################################################
function ImportConf
{
	local conf="${FILE_CONF}"

	if [[ -f "${conf}" ]];then
		source "${conf}"
	else
		Echo "config file ${conf} not exist! please check." >> ${FILE_RUNINFO}
		Exit
	fi

	if [[ -z "${DIR_CLEAR}" ]];then
		Echo "DIR_CLEAR in ${conf} not configure! please check." >> ${FILE_RUNINFO}
		Exit
	fi

	if [[ -z "${KEEP_TIME_MAX}" ]];then
		Echo "KEEP_TIME_MAX in ${conf} not configure! please check." >> ${FILE_RUNINFO}
		Exit
	elif ! (( ${KEEP_TIME_MAX}>0 ));then
		Echo "KEEP_TIME_MAX in ${conf} not a positive integer! please check." >> ${FILE_RUNINFO}
		Exit
	fi

	if [[ -z "${DISK_SPACE_MIN}" ]];then
		Echo "DISK_SPACE_MIN in ${conf} not configure! please check." >> ${FILE_RUNINFO}
		Exit
	elif ! (( ${DISK_SPACE_MIN}>0 ));then
		Echo "DISK_SPACE_MIN in ${conf} not a positive integer! please check." >> ${FILE_RUNINFO}
		Exit
	fi

	if [[ -z "${DISK_SPACE_MAX_RATE}" ]];then
		Echo "DISK_SPACE_MAX_RATE in ${conf} not configure! please check." >> ${FILE_RUNINFO}
		Exit
	elif ! (( ${DISK_SPACE_MAX_RATE}>0 ));then
		Echo "DISK_SPACE_MAX_RATE in ${conf} not a positive integer! please check." >> ${FILE_RUNINFO}
		Exit
	fi

	if [[ -z "${KEEP_TIME_MIN}" ]];then
		Echo "KEEP_TIME_MIN in ${conf} not configure! please check." >> ${FILE_RUNINFO}
		Exit
	elif ! (( ${KEEP_TIME_MIN}>0 ));then
		Echo "KEEP_TIME_MIN in ${conf} not a positive integer! please check." >> ${FILE_RUNINFO}
		Exit
	fi

	local is_exit=0
	
	echo ${DIR_CLEAR} | awk -v RS=";" '{print $1}' | while read line
	do
		local dir_clear=$(echo ${line} | awk -F',' '{print $1}')
		local depth=$(echo ${line} | awk -F',' '{print $2}')
		local reg_exp=$(echo ${line} | awk -F',' '{print $3}')
	
		if ! [[ -d "${dir_clear}" ]];then
			Echo "${dir_clear} in ${conf} not directory! please check." >> ${FILE_RUNINFO}
			exit 1
		fi

		if [[ -z "${depth}" ]];then
			Echo "DIR_CLEAR in ${conf} configure wrong! please check." >> ${FILE_RUNINFO}
			exit 1
		elif ! (( ${depth}>0 ));then
			Echo "DIR_CLEAR in ${conf} configure wrong! please check." >> ${FILE_RUNINFO}
			exit 1
		fi
	done

	is_exit=$?

	if ((${is_exit}!=0));then
		Exit
	fi
}
########################################################################

########################################################################
# 函 数 名  : DeployCron
# 功能描述  : 在脚本第一次运行是配置定时任务，将本设置为每小时的10分运行
# 输入参数  : 无
# 返 回 值  : 无
# 调用函数  : 无
# 修改历史      :
#  1.日    期   : 2014年09月01日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
########################################################################
function DeployCron
{
	local script="${DIR_INSTALL}/${SCRIPT_NAME}.sh"
	
	if ! egrep -q "${script}" /etc/crontab;then
		echo "10 * * * * root ${script}" >> /etc/crontab
		Echo "create crontab \"10 * * * * root ${script}\"" >> ${FILE_RUNINFO}
		Exit
	fi
}
########################################################################

########################################################################
# 函 数 名  : GetFileTime
# 功能描述  : 计算文件时间
# 输入参数  : 文件绝对路径
# 返 回 值  : 文件UTC时间
# 调用函数  : 无
# 修改历史      :
#  1.日    期   : 2014年08月29日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
########################################################################
function GetFileTime
{
	local file="$1"
	file_sec=$(stat -c %Y ${file})
	echo ${file_sec}
}
########################################################################

########################################################################
# 函 数 名  : FileDelete
# 功能描述  : 根据时间、磁盘空间等信息判断是否删除文件
# 输入参数  : 文件绝对路径
# 返 回 值  : 文件删除日志
# 调用函数  : Echo
# 修改历史      :
#  1.日    期   : 2014年08月29日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
#  2.日    期   : 2014年09月02日
#    作    者   : 曹海涛
#    修改内容   : 优化告警策略
########################################################################
function FileDelete
{
	local delete_file="$1"
	local utc_now=$(date +'%s')
	local file_sec=$(GetFileTime ${delete_file})
	local disk_space_remain=$(df -m ${delete_file} | tail -1 | awk '{print $4}')
	local disk_space_rate=$(df -m ${delete_file} | tail -1 | awk '{print $5}' | awk -F'%' '{print $1}')

	local interval=$(( (${DATE_NOW}-${file_sec})/3600 ))
	local disk_space_remain_GB=$((${disk_space_remain}/1024))
	
	if (( ${interval}>${KEEP_TIME_MAX} || ${disk_space_remain_GB}<${DISK_SPACE_MIN} || ${disk_space_rate}>${DISK_SPACE_MAX_RATE} ));then
		if (( ${interval}>${KEEP_TIME_MAX} ));then
			rm -rf ${delete_file}
			Echo "delete ${delete_file}" >> ${FILE_LOG_NORMAL}
		elif (( ${interval}>${KEEP_TIME_MIN} ));then
			rm -rf ${delete_file}
			echo "${utc_now},1,1,$(dirname ${delete_file}) not have enough space and delete ${delete_file}" >> ${FILE_LOG_ERROR}
		else
			echo "${utc_now},1,1,$(dirname ${delete_file}) not have enough space" >> ${FILE_LOG_ERROR}
		fi
	fi
}
########################################################################

########################################################################
# 函 数 名  : Main
# 功能描述  : 入口函数，解析配置文件，调用目录遍历函数
# 输入参数  : 无
# 返 回 值  : 无
# 调用函数  : ListDir
# 修改历史      :
#  1.日    期   : 2014年08月29日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
########################################################################
function Main
{
	echo ${DIR_CLEAR} | awk -v RS=";" '{print $1}' | while read line
	do
		local dir_clear=$(echo ${line} | awk -F',' '{print $1}')
		local depth=$(echo ${line} | awk -F',' '{print $2}')
		local reg_exp=$(echo ${line} | awk -F',' '{print $3}')
		
		#if [[ -z ${reg_exp} ]];then
		#	reg_exp=".*"
		#fi

		reg_exp="${REG_EXP}"

		ListDir "${dir_clear}" "${depth}" "${reg_exp}"
	done
}
########################################################################

########################################################################
# 函 数 名  : ListDir
# 功能描述  : 目录遍历函数，通过递归调用对目录进行指定深度的扫描。
#             并对扫描到的每个文件名称进行规则匹配并调用FileDelete
# 输入参数  : 目录路径、扫描深度、文件命名规则
# 返 回 值  : 无
# 调用函数  : ListDir、FileDelete
# 修改历史      :
#  1.日    期   : 2014年08月29日
#    作    者   : 曹海涛
#    修改内容   : 新生成函数
########################################################################
function ListDir
{
	local dir="$1"
	local depth="$2"
	local exp="$3"

	if [[ -z ${exp} ]];then
		exp=".*"
	fi

	ls -1t ${dir} | tac | egrep "${exp}" | while read file
	do
		if [[ -d "${dir}/${file}" ]] && ((${depth}>1));then
			local depth_sub=${depth}
			((depth_sub--))
			ListDir "${dir}/${file}" "${depth_sub}"
			
			local file_num=$(ls -1 ${dir}/${file} | wc -l)
			if ((${file_num}==0));then
				rm -rf "${dir}/${file}"
				Echo "delete empty directory ${dir}/${file}" >> ${FILE_LOG_NORMAL}
			fi
		else
			FileDelete "${dir}/${file}"
		fi
	done
}
########################################################################


########################################################################
# BEGINNING OF MAIN
########################################################################
PS4='+[$LINENO:${FUNCNAME[0]:-$0}()]'
shopt -s expand_aliases

InitEnv
ImportConf
DeployCron
Main
Exit
########################################################################
# End of script
########################################################################
