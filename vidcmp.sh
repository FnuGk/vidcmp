#!/bin/bash


VID1=$1
VID2=$2
shift 2

if [ "$VID1" == "$VID2" ]; then
    exit 1
fi

# Requires ffmpeg and imagemagick (compare)

# if ffmpeg does not exists asume we have libav avconv instead
FFMPEG=ffmpeg
FFPROBE=ffprobe
# $FFMPEG -version
# if [ "$?" -ne "0" ]; then
#     FFMPEG=avconv
#     FFPROBE=avprobe
# fi

EQUAL="$VID1 EQUAL $VID2"
NOT_EQUAL="$VID1 NOT equal $VID2"



THRESHOLD=21.0

# First we simply just compare the run time and exit if they dont match
VID_LEN1=$($FFPROBE -i "$VID1" -show_entries format=duration -v quiet -of default=noprint_wrappers=1) #| cut -c10-)
VID_LEN2=$($FFPROBE -i "$VID2" -show_entries format=duration -v quiet -of default=noprint_wrappers=1) #| cut -c10-)
VID_LEN1=${VID_LEN1:9} # Cut of the first nine chars (duration=)
VID_LEN2=${VID_LEN2:9}

if [[ "$VID_LEN1" != "$VID_LEN2" || -z "$VID_LEN1" || -z "$VID_LEN2" || "$VID_LEN1" == "N/A" || "$VID_LEN2" == "N/A" ]]; then
    echo "$NOT_EQUAL (Runtime mismatch)"
    exit 1
fi

TMP_DIR=/tmp/$$ # ehere $$ is the pid
mkdir -p $TMP_DIR/1
mkdir -p $TMP_DIR/2
START_TIME="-ss 00:01"

if [[ "$(echo "$VID_LEN1 > (12 * 60)" | bc)" -eq "1" ]]; then
    frame_rate="-r 0.0033" # (1/0.0033)/60 = about 5 minutes
elif [[ "$(echo "$VID_LEN1 > (5 * 60)" | bc)" -eq "1" ]]; then
    frame_rate="-r 0.01" # 1/0.01 = 100 sec
else
    frame_rate="-r 0.1"  # 1/0.1 = 10 sec
fi

# Create still frames from each video
$FFMPEG $START_TIME -i "$VID1" $frame_rate -f image2 $TMP_DIR/1/img-%3d.jpg && \ #>/dev/null 2>&1
$FFMPEG $START_TIME -i "$VID2" $frame_rate -f image2 $TMP_DIR/2/img-%3d.jpg      #>/dev/null 2>&1
if [ "$?" -ne "0" ]; then
    echo "$NOT_EQUAL (ffmpeg failed)"
    rm -r $TMP_DIR
    exit 1
fi

cnt=0
total_phash=0
for f in $(ls $TMP_DIR/1 | sort); do
    phash=$(compare -channel all -metric phash $TMP_DIR/1/$f $TMP_DIR/2/$f /dev/null 2>&1)
    total_phash=$(echo "$total_phash + $phash" | bc -l)
    ((cnt++))
done

avg_phash=$(echo "$total_phash / $cnt" | bc -l)
is_match=$(echo "$avg_phash > $THRESHOLD" | bc -l)
if [ "$is_match" -ne "0" ]; then
    echo "$NOT_EQUAL (avg phash: $avg_phash > $THRESHOLD)"
else
    echo "$EQUAL (avg phash: $avg_phash < $THRESHOLD)"
fi

rm -r $TMP_DIR
exit $is_match
