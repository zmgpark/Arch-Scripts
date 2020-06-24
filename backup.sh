#!/bin/bash

# Version Alpha 1.0

########## Script DEPENDENCIES ##########
# openssh (on a remote machine too)
# calc
# rsync

# EDIT THESE VARIABLES
# remote_ip="192.168.1.195" # edit this if you want to backup files from another computer through ssh 
# user="daneel" # You might want to use this if there are more than one user you want to backup
# path_2_backup="/home/$user"
# exclude_file="/home/tempgisk/exclude/exclude_$user.txt"
# path_backups="/home/tempgisk/backup"

remote_ip="" # edit this if you want to backup files from another computer through ssh 
user="" # this also.
path_2_backup="/home/daneel/music/ASMR/"
exclude_file="/home/daneel/prueba/exclude.txt"
path_backups="/home/daneel/prueba"

###########################################################################
# DO NOT EDIT ANYTHING AFTER THIS UNLESS YOU KNOW WHAT YOU ARE DOING
# actual_date="$(date "+%d-%m-%y")"
# current_day="$(date "+%d" | sed 's/^0//')"
# current_month="$(date "+%m" | sed 's/^0//')"
# current_year="$(date "+%y" | sed 's/^0//')"
# path_destination="$path_backups/d.1_bckp_$actual_date/"
###########################################################################
# FOR DEBUGGING COMMENT EVERYTHING ON THE BLOCK ABOVE
# UNCOMMENT THIS BLOCK EXCEPT THIS ADVICE

if check_exist; then
    actual_date=$(ls ${path_backups}/ | grep -F "d1" | cut -d '_' -f3)
    current_day=$(echo $actual_date | cut -d '-' -f1)
    current_month=$(echo $actual_date | cut -d '-' -f2)
    current_year=$(echo $actual_date | cut -d '-' -f3)
else
    actual_date="$(date "+%d-%m-%y")"
    current_day="$(date "+%d" | sed 's/^0//')"
    current_month="$(date "+%m" | sed 's/^0//')"
    current_year="$(date "+%y" | sed 's/^0//')"
    path_destination="$path_backups/d.1_bckp_$actual_date/"
fi

function debugging {
}
###########################################################################

[ ! -f $exclude_file ] && touch $exclude_file

function date2days {
    local days=$1
    local months=$2
    local year=$3
    local num_days=0
    if [ $months -ne $current_month ]; then
        while [ $months -ne $current_month ] && [ $year -le $current_year ]; do
            case $months in
                2)
                    div=$(calc -p "$year%4")
                    if [ $div -eq 0 ]; then
                        num_days=$(( $num_days + 29 ))
                    else
                        num_days=$(( $num_days + 28 ))
                    fi
                    ;;
                1|3|5|7|8|10|12)
                    num_days=$(( $num_days + 31 ))
                    ;;
                *)
                    num_days=$(( $num_days + 30 ))
                    ;;
            esac
            if [ $months -eq 12 ]; then
                months=0
                year=$(( $year + 1 ))
            fi
            months=$(( $months + 1 ))
        done
        num_days=$(( $num_days - $days + $current_day ))
    else
        num_days=$(( $current_day - $days ))
    fi
    echo $num_days
}

function check_exist {
    if ls -l $path_backups | grep -Fq "bckp"; then
        return
    fi
    false
}

function check_type_exist {
    local bckp_type="$1"
    if ls -l $path_backups/ | grep -Fq "${bckp_type}.1"; then
        return
    fi
    false
}

function findmaxoftype {
    local bckp_type="$1"
    local bckp_specific_nums=()
    if check_type_exist "$bckp_type"; then
        bckp_specific_nums=($( ls -l $path_backups/ | grep -F "${bckp_type}." | awk '{print $9}' | cut -d '.' -f2 | cut -d '_' -f1))
        local num=0
        for i in ${bckp_specific_nums[@]}; do
            if [ $num -lt $i ]; then
                num=$i
            fi
        done
        echo $num
    fi
}

function eliminate_old {
    local backups=($(ls -l $path_backups | grep -F "bckp" | awk '{print $9}'))
    for i in ${backups[@]}; do
        local year=$(echo $i | cut -d '_' -f3 | cut -d '-' -f3 | sed 's/^0//')
        local month=$(echo $i | cut -d '_' -f3 | cut -d '-' -f2 | sed 's/^0//')
        local day=$(echo $i | cut -d '_' -f3 | cut -d '-' -f1 | sed 's/^0//')
        local days_since=$(date2days $day $month $year)
        if [ $days_since -gt 140 ]; then
            rm -rf "${path_backups}/${i}"
        fi
    done
}

# This checks if m1 is ready to move and exist;
# returns false if m type doesn't exist or is not ready to move
function check_ready {
    local bckp_type=$1
    if check_type_exist "$bckp_type"; then
        local file=$(ls -l $path_backups | grep -F "bckp" | grep "${bckp_type}.1" | awk '{print $9}')
        local day=$(echo $file | cut -d '_' -f3 | cut -d '-' -f1 | sed 's/^0//')
        local month=$(echo $file | cut -d '_' -f3 | cut -d '-' -f2 | sed 's/^0//')
        local year=$(echo $file | cut -d '_' -f3 | cut -d '-' -f3 | sed 's/^0//')
        local days_since=$(date2days $day $month $year)
        local max=0
        case $bckp_type in
            m)
                max=56
                ;;
            s)
                max=14
                ;;
            d)
                max=0
                ;;
            *)
                echo ERROR
                ;;
        esac
        if [ $days_since -gt $max ]; then
            return
        fi
    fi
    false
}

function asc_bckp {
    local bckp_type="$1"
    if check_ready "$bckp_type"; then
        local num_file=$(findmaxoftype "$bckp_type")
        while [ $num_file -ge 1 ]; do
            local file=$(ls -l $path_backups | grep -F "bckp" | grep "${bckp_type}.${num_file}" | awk '{print $9}')
            local num_file_after=$(( $num_file + 1 ))
            case $bckp_type in
                m)
                    if [ $num_file -eq 4 ]; then
                        rm -rf "${path_backups}/${file}"
                    else
                        mv "${path_backups}/${file}" "${path_backups}/m.${num_file_after}_${file#*_}"
                    fi
                    ;;
                s)
                    if [ $num_file -eq 4 ] && ! check_type_exist "m"; then
                        cp -al "${path_backups}/${file}" "${path_backups}/m.1_${file#*_}"
                        rm -rf "${path_backups}/${file}"
                    elif [ $num_file -eq 4 ]; then
                        rm -rf "${path_backups}/${file}"
                    else
                        mv "${path_backups}/${file}" "${path_backups}/s.${num_file_after}_${file#*_}"
                    fi
                    ;;
                d)
                    if [ $num_file -eq 7 ] && ! check_type_exist "s"; then
                        cp -al "${path_backups}/${file}" "${path_backups}/s.1_${file#*_}"
                        rm -rf "${path_backups}/${file}"
                    elif [ $num_file -eq 7 ]; then
                        rm -rf "${path_backups}/${file}"
                    elif [ $num_file -eq 1 ]; then
                        cp -al "${path_backups}/${file}" "${path_backups}/d.${num_file_after}_${file#*_}"
                        mv "${path_backups}/${file}" "$path_destination"
                    else
                        mv "${path_backups}/${file}" "${path_backups}/d.${num_file_after}_${file#*_}"
                    fi
                    ;;
                *)
                    echo ERROR
                    ;;
            esac
            num_file=$(( $num_file - 1 ))
        done
    fi
}

function backup_now {
    if [[ ! $remote_ip == "" ]]; then
        rsync -avvzz --exclude-from=$exclude_file --delete $user@$remote_ip:$path_2_backup $path_destination &> /dev/null
    else
        rsync -avv --exclude-from=$exclude_file --delete $path_2_backup $path_destination &> /dev/null
    fi
}

function main {
    if check_exist; then
        eliminate_old
        asc_bckp "m"
        asc_bckp "s"
        asc_bckp "d"
    fi 
    backup_now
}

main
