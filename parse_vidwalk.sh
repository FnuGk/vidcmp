#!/bin/bash

IFS=$'\n' walk_output=( $(cat $1) )

len=${#walk_output[@]}
for (( i=0; i<$len; i++ )); do
    line=${walk_output[$i]}

    file1=${line% EQUAL*} # Everything before first match of EQUAL

    file2=${line#*EQUAL } # Everything after first match of EQUAL
    file2=${file2% (avg phash*} # remove the info about phash

    avg_phash=${line#*(avg phash\: }
    avg_phash=${avg_phash% < *}

    bit_rate1=$(ffprobe -v quiet -show_format -i "$file1" | grep bit_rate | cut -d'=' -f2)
    bit_rate2=$(ffprobe -v quiet -show_format -i "$file2" | grep bit_rate | cut -d'=' -f2)

    echo $file1
    echo $file2

    if [[ "$(echo "$avg_phash < 21" | bc -l)" -eq "1" ]]; then
        if ! ([[ "$file1" == *wmv ]] && [[ "$file2" == *wmv ]]); then
            if [[ "$file1" == *wmv ]]; then
                echo "wmv"
                rm "$file1"
                continue
            elif [[ "$file2" == *wmv ]]; then
                echo "wmv"
                rm "$file2"
                continue
            fi
        fi

        if [[ "$bit_rate1" -gt "$bit_rate2" ]]; then
            echo "$bit_rate1 > $bit_rate2"
            rm "$file2"
        elif [[ "$bit_rate1" -lt "$bit_rate2" ]]; then
            echo "$bit_rate1 < $bit_rate2"
            rm "$file1"
        else
            echo "$bit_rate1 == $bit_rate2"
            rm "$file2"
        fi
    fi
done
