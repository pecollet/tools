#!/bin/bash

#get names of rotated files xxx.csv.1, xxx.csv.2 ,etc
get_rotated_files() {
	local str=""
	local OLD_FILES=${1}.[0-9]*
	for old_f in $OLD_FILES
	do
		[ -e "${old_f}" ] || continue
		str="${str} ${old_f}"
	done
	echo ${str}
}

#validate inputs
if [[ $# -lt 1 || $# -eq 2 ]]; then
    echo "Usage $0 <metrics_dir> [<rangeStart> <rangeEnd>]";
    echo "   with optional range expressed with epoch values" && exit;
fi

#getting execution directory
prg=$0
if [ ! -e "$prg" ]; then
  case $prg in
    (*/*) exit 1;;
    (*) prg=$(command -v -- "$prg") || exit;;
  esac
fi
dir=$(cd -P -- "$(dirname -- "$prg")" && pwd -P) || exit

OUTPUT_FILE=metrics${2}_${3}.html
cd ${1}
echo '<HTML><HEAD><TITLE>Neo4j Metrics</TITLE></HEAD><BODY>' > ${OUTPUT_FILE}
FILES=*.csv
for f in $FILES
do
  [ -e "${f}" ] || continue
  echo "Processing ${f}"
  fileset="${f} $(get_rotated_files ${f})"
  file_count=$(echo ${fileset} |wc -w)
  echo "    plotting data from ${file_count} file(s)"
  #plot column 2 of each file in the set, for the specified range
  gnuplot -p -c ${dir}/neo.metrics.gnuplot_png "${fileset}" 2 ${2} ${3}
  #writing the result to a html report (img of the chart + zero-size text for search)
  echo '<img src="'${f}'.png" border=1><small style="font-size: 0px;">'${f}'</small>' >> ${OUTPUT_FILE}
done
echo '</BODY></HTML>' >> ${OUTPUT_FILE}
echo "Done."