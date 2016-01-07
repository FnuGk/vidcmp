#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

MAX_JOBS=$(getconf _NPROCESSORS_ONLN)

#n_files=$(find . -not -name "*.part" -not -iname "*.jpg" -not -iname "*.jpeg" -type f 2>/dev/null | wc -l)

# Simple implementation O(n^2)
# cnt=0
# find . -not -name "*.part" -not -iname "*.jpg" -not -iname "*.jpeg" -type f -print0 2>/dev/null | while read -d $'\0' file1; do
#     ((cnt++))
#     progress=$(echo "$cnt / $n_files * 100" | bc -l)
#     >&2 echo "Progress: $cnt/$n_files ($progress%)" # print progress to stderr
#
#     find . -not -name "*.part" -not -iname "*.jpg" -not -iname "*.jpeg" -type f -print0 2>/dev/null | xargs -P10 -0 -I {} $DIR/vidcmp.sh "$file1" {}
# done

#FIND='find . -not -name "*.part" -not -iname "*.jpg" -not -iname "*.jpeg" -type f -print0'

# run_times=""
# for rt in $($FIND 2>/dev/null | xargs -P10 -0 -I % ffprobe -i % -show_entries format=duration -v quiet -of default=noprint_wrappers=1); do
#     run_times="$run_times ${rt:9}"
# done
#
# i=0
# j=0
# for rt1 in $run_times; do
#     ((i++))
#
#     progress=$(echo "$i / $n_files * 100" | bc -l)
#     >&2 echo "Progress: $i/$n_files ($progress%)" # print progress to stderr
#
#     for rt2 in $run_times; do
#         ((j++))
#         if [[ "$rt1" == "$rt2" && "$rt1" != "N/A" && "$rt2" != "N/A" ]]; then # must have equal runtime
#             if [[ "$i" -ne "$j" ]]; then # must not be the same file
#                 ii=0
#                 jj=0
#                 $FIND 2>/dev/null | while read -d $'\0' file1; do
#                     ((ii++))
#                     if [[ "$i" -eq "$ii" ]]; then
#                         $FIND 2>/dev/null | while read -d $'\0' file2; do
#                             ((jj++))
#                             if [[ "$j" -eq "$jj" ]]; then
#                                 # </dev/null added to prevent http://mywiki.wooledge.org/BashFAQ/089
#                                 # as descriped at http://unix.stackexchange.com/a/36411
#                                 < /dev/null $DIR/vidcmp.sh "$file1" "$file2" 2>/dev/null
#                             fi
#                         done
#                         jj=0
#                     fi
#                 done
#             fi
#         fi
#         ii=0
#     done
#     j=0
# done

#black_list_formats="part jpg jpeg nfo"

# TODO make this whitelist work so code i pretty
# white_list_formats="mp4 m4v wmv mpg mpeg avi flv mov mkv webm"
# white_list=""
# for format in $white_list_formats; do
#     fmt="-iname \"*.$format\""
#     white_list="$white_list $fmt"
# done

IFS=$'\n' files=( $(find "$1" -type f \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.wmv" -o -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.avi" -o -iname "*.flv" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.webm" \) -print  2>/dev/null) )
#IFS=$'\n' files=( $(find . -not -name "*.part" -not -iname "*.jpg" -not -iname "*.jpeg" -not -iname "*.nfo" -type f -print 2>/dev/null) )

n=${#files[@]}

run_times=""
for (( i=0; i<$n; i++ )); do
    rt=$(ffprobe -i ${files[$i]} -show_entries format=duration -v quiet -of default=noprint_wrappers=1)
    run_times[$i]=${rt:9}

    progress=$(echo "$i / $n * 100" | bc -l)
    >&2 echo "ffprobe Progress: $i/$n ($progress%)" # print progress to stderr
done

visisted="" # keep track of what have already been compared so it is not compared twice (1 vs 2 and then 2 vs 1)

for (( i=0; i<$n; i++ )); do
    progress=$(echo "$i / $n * 100" | bc -l)
    >&2 echo "Progress: $i/$n ($progress%)" # print progress to stderr

    rt1=${run_times[$i]}
    f1=${files[$i]}

    if [[ -z "$rt1" || "$rt1" == "N/A" ]]; then
        continue
    fi

    for (( j=0; j<$n; j++ )); do
        rt2=${run_times[$j]}
        f2=${files[$j]}

        if [[ -z "$rt2" || "$rt2" == "N/A" ]]; then
            continue
        fi

        if [[ $f1 != $f2 && "$rt1" == "$rt2" && "${visisted[$i]}" -ne "$j" ]]; then
            < /dev/null $DIR/vidcmp.sh "$f1" "$f2" 2>/dev/null &
            visisted[$j]="$i"

            # if [[ "$(jobs -p | wc -l)" -eq "$MAX_JOBS" ]]; then
            #     wait $(jobs -p | head -n 1) #$(jobs -p)
            # fi
            while [[ "$(jobs -p | wc -l)" -eq "$MAX_JOBS" ]]; do
                sleep 10
            done
        fi
    done
done
wait #$(jobs -p)
