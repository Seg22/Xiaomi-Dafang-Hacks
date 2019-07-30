#!/bin/sh

# Takes a snapshot every N seconds interval configured
# in /system/sdcard/config/timelapse.conf

PIDFILE='/run/timelapse.pid'
TIMELAPSE_CONF='/system/sdcard/config/timelapse.conf'
BASE_SAVE_DIR='/system/sdcard/DCIM/timelapse'

if [ -f "$TIMELAPSE_CONF" ]; then
    . "$TIMELAPSE_CONF" 2>/dev/null
fi

if [ -z "$TIMELAPSE_INTERVAL" ]; then TIMELAPSE_INTERVAL=2.0; fi


# because``date`` doesn't support milliseconds +%N
# we have to use a running counter to generate filenames
counter=1
#last_prefix=''
ts_started=$(date +%s)

SAVE_DIR=$BASE_SAVE_DIR
    if [ $SAVE_DIR_PER_DAY -eq 1 ]; then
        SAVE_DIR="$BASE_SAVE_DIR/$(date +%Y-%m-%d)"
    fi
    if [ ! -d "$SAVE_DIR" ]; then
        mkdir -p $SAVE_DIR
    fi

	if [ $TIMELAPSE_DURATION -eq 0 ]; then
	TIMELAPSE_LENGTH=0
	fi
	
	TIMELAPSE_INTERVAL_MIN=$TIMELAPSE_INTERVAL
	
	#determins the Timelapse intevale depending on the set timelapse length
	if [ $TIMELAPSE_LENGTH != 0 ]; then
        TIMELAPSE_INTERVAL=$(($TIMELAPSE_DURATION*60/$TIMELAPSE_LENGTH/30))
    fi
	
	if [ $TIMELAPSE_INTERVAL -le $TIMELAPSE_INTERVAL_MIN ]; then
	TIMELAPSE_INTERVAL=$TIMELAPSE_INTERVAL_MIN
	fi
	
while true; do
    #filename_prefix="$(date +%Y-%m-%d_%H%M%S)"
    #if [ "$filename_prefix" = "$last_prefix" ]; then
    #    counter=$(($counter + 1))
    #else
    #    counter=1
    #    last_prefix="$filename_prefix"
    #fi
    counter_formatted=$(printf '%05d' $counter)
    filename="img${counter_formatted}.jpg"
    if [ -z "$COMPRESSION_QUALITY" ]; then
         /system/sdcard/bin/getimage > "$SAVE_DIR/$filename" &
    else
        /system/sdcard/bin/getimage | /system/sdcard/bin/jpegoptim -m"$COMPRESSION_QUALITY" --stdin --stdout > "$SAVE_DIR/$filename" &
    fi
		
    sleep $TIMELAPSE_INTERVAL

    if [ $TIMELAPSE_DURATION -gt 0 ]; then
        ts_now=$(date +%s)
        elapsed=$(($ts_now - $ts_started))
        if [ $(($TIMELAPSE_DURATION * 60)) -le $elapsed ]; then
            break
        fi
    fi
	counter=$(($counter + 1))
done

# loop completed so let's purge pid file
rm "$PIDFILE"

#switch current folder to timelapse
cd $SAVE_DIR

wc -c *.jpg > tmp3.txt
lines2=$(cat tmp3.txt | wc -l)
sed -n $((lines2))p tmp3.txt > tmp4.txt
B=$(grep -o "[0-9]*" tmp4.txt)
average=$(($B/$lines2))

#write all imagefiles over 55kb into temp file
find . -type f -size -$(($average-$average/20))c -iname '*.jpg' > tmp1.txt
#take only the numbers out of first temp file and write into another
grep -o "[0-9]*" tmp1.txt > tmp2.txt

#set counter and get number of lines 
counter=1
lines=$(cat tmp2.txt | wc -l)

while [ $counter -le $lines ]; do
    #get the first line, then second line etc. 
	X=$(sed -n $(($counter))p tmp2.txt)
	#get first line, delete leading zeros add +1 and add leading zeros again
	Y=$(echo $X | sed -e 's/^0*//')
	Z=$(($Y+1))
	A=$(printf '%05d' "$Z")
	#Y+Z+A together
	#H=$(printf '%05d' "$(($(($(echo $X | sed -e 's/^0*//')+1))))")
	cp img$A.jpg img$X.jpg
	counter=$(($counter + 1))
	done
rm tmp1.txt
rm tmp2.txt
rm tmp3.txt
rm tmp4.txt

/system/sdcard/bin/avconv -y -r 30 -f image2 -i img%05d.jpg  $(date +%Y-%m-%d_%H%M%S).mov
#rm *.jpg
