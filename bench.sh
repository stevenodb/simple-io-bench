#!/usr/bin/env bash

file=bigfile
copy="${file}.copy"
# size of bigfile is expressed as power of 2.
EXP=32

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[0;31m'
NC='\033[0m' # No Color

function calculate_rate {
	rate=$(echo -n "$2" | sed -nE 's#^.*\(([0-9]+) bytes/sec.*$#\1#p' | awk 'END { gb = $1 / 1024**3 ; printf("%.2f GiB/s\n", gb)}')
	echo -e "$1 ${RED}$rate${NC}"
}

function create_content {
  END=$((EXP-4))

	echo -n "wubba lubba dub " > ${file}
  for i in $(seq $END); 
  do
    cat ${file} ${file} > ${file}.2; mv ${file}.2 ${file};
    pct=$(( i * 100 / $END ))
    if (( $i & 1 )) || (($i == $END)); then 
      echo -ne "\r"
      echo -n "progress: ${pct}%";
    fi
  done
}

function message {
	echo -e "${BOLD}$1${NORMAL}"
}

function humanize {
	local result=$(echo "$1" | awk '{ byte = $1 /1024**2 ; print byte " MiB" }')
	echo "$result"
}

function cleanup {
  if [ -f ${file} ]; then
    message "\nClean up?"
    rm -i ${file} ${file}.*
  fi
}

function create_file {
  if [ ! -f ${file} ]; then
    size=$(humanize $((2**EXP)))
    message "\nCreating ${file} of size ${size} bytes with non-null content..."
    create_content
  else
    message "\nReusing existing file."
  fi
}

function spin_up_sudo {
  if [[ $EUID -ne 0 ]]; then
    message "\nNeed sudo rights to purge disk caches after writing."
    sudo -v
  fi
}

function do_copy {
  message "\nCopying ${file} to ${copy}..."
  message "$ dd if=${file} bs=1024k of=${copy}"
  calculate_rate "COPY rate:" "${RED}$(dd if=${file} bs=1024k of=${copy} conv=swab 2>&1)${NC}"
}

function do_purge {
  message "\nPurging disk caches..."
  message "$ sudo purge"
  sudo purge
}

function do_read {
  message "\nWe read the file back in..."
  message "$ dd if=${file} bs=1024k of=/dev/null count=1024"
  calculate_rate "READ rate:" "$(dd if=${file} bs=1024k of=/dev/null 2>&1)"
  calculate_rate "CACHED READ rate" "$(dd if=${file} bs=1024k of=/dev/null 2>&1)"
}

clear
cat <<'_EOF'
%{-------------------------------------------------------------------------+
 |  ___    _____    ____                  _                          _     |
 | |_ _|  / / _ \  | __ )  ___ _ __   ___| |__  _ __ ___   __ _ _ __| | __ |
 |  | |  / / | | | |  _ \ / _ \ '_ \ / __| '_ \| '_ ` _ \ / _` | '__| |/ / |
 |  | | / /| |_| | | |_) |  __/ | | | (__| | | | | | | | | (_| | |  |   <  |
 | |___/_/  \___/  |____/ \___|_| |_|\___|_| |_|_| |_| |_|\__,_|_|  |_|\_\ |
 |                                                                         |
 | Simple I/O Benchmark that creates, copies and reads a big file          |
 | Steven Op de beeck, 2018.                                               |
 +-------------------------------------------------------------------------%}
_EOF

cleanup
create_file
sync

echo "" ; ls -lh ${file}*

spin_up_sudo
do_copy
do_purge
do_read

echo "" ; ls -lh ${file}*
cleanup