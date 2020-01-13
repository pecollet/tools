#!/bin/bash

usage () {
    echo "Usage: $0 log_directory"
}

if [ -z "$1" ] ; then
   usage
else
    log_dir=${1}
    debug_log=${log_dir}/debug.log

    echo "Parsing debug log: ${debug_log}"
    version=$(grep "Kernel version:" ${debug_log} |tail -1 |cut -d" " -f7 |cut -d"," -f1)
    echo "Version : ${version}"
    if [[ $version == 4* ]]; then
        grep "\[ System memory information \]"  -A13 -B1 ${debug_log}
        grep "\[ DBMS config \]" -B1 -A50 ${debug_log} | grep "DiagnosticsManager"
        grep "\[ Store files \]" -B1 -A48 ${debug_log}
    else
        grep "Disk space on partition" ${debug_log} 
        grep "dbms.memory" ${debug_log}
        grep '\- Total' ${debug_log} -B1 -A40
        #Neo4j Kernel properties:
    fi
fi