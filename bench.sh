#!/usr/bin/env bash

file=bigfile
copy="${file}.copy"
# size of bigfile is expressed as power of 2.
EXP=30

bold=$(tput bold)
normal=$(tput sgr0)

function calculate_rate {
	rate=$(echo -n "$2" | sed -nE 's#^.*\(([0-9]+) bytes/sec.*$#\1#p' | awk 'END { gb = $1 / 1024**3 ; printf("%.2f GiB/s\n", gb)}')
	echo -e "$1 $rate"
}

function create_content {
	echo -n "wubba lubba dub " > ${file}; for i in $(seq "$((EXP-4))"); do cat ${file} ${file} > ${file}.2; mv ${file}.2 ${file} ; done
}

function message {
	echo -e "${bold}$1${normal}"
}

function humanize {
	local result=$(echo "$1" | awk '{ byte = $1 /1024**2 ; print byte " MiB" }')
	echo "$result"
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

if [ -f ${file} ]; then
	message "\nClean up?"
	rm -i ${file} ${file}.*
fi

if [ ! -f ${file} ]; then
	size=$(humanize $((2**EXP)))
	message "\nCreating ${file} of size ${size} bytes with non-null content ..."
	create_content
else
	message "\nReusing existing file."
fi

sync
echo ""
ls -lh ${file}*

if [[ $EUID -ne 0 ]]; then
   message "\nNeed sudo rights to purge disk caches after writing."
   sudo -v
fi

message "\nCopying ${file} to ${copy} ..."
message "$ dd if=${file} bs=1024k of=${copy}"
time calculate_rate "COPY rate:" "$(dd if=${file} bs=1024k of=${copy} conv=swab 2>&1)"


message "\nPurging disk caches..."
message "$ sudo purge"
sudo purge


message "\nWe read the file back in..."
message "$ dd if=${file} bs=1024k of=/dev/null count=1024"
calculate_rate "READ rate:" "$(dd if=${file} bs=1024k of=/dev/null 2>&1)"
calculate_rate "CACHED READ rate" "$(dd if=${file} bs=1024k of=/dev/null 2>&1)"
echo ""

ls -lh ${file}*