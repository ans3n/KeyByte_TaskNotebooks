#!/bin/bash
#########################################################################
# File Name: run.sh
# Author: Lin Ma
# mail: malin1993ml@gmail.com
# Created Time: 03/04/17
#########################################################################

trap onexit 1 2 3 15
function onexit() {
    local exit_status=${1:-$?}
    pkill -f rnn.tag
    exit $exit_status
}

USAGE='usage: run.sh input_folder output_folder'

if [ "$#" -ne 2 ]; then
    echo $USAGE
    exit
fi

mkdir -p $2

for file in `find $1 -type f`
do
    filename=`basename $file`
    if [[ $filename == *"schema"* ]]; then
        command="cp $file $2/"
    else
        if [ -f $2/$filename.anonymized.gz ]; then
            continue
        fi
        command="./log-anonymizer.py --type mysql --version 5.5 $file | gzip --best > $2/$filename.anonymized.gz"
    fi

    if [ ! -f "$2/$filename.anonymized.gz" ]; then
        echo $command
        eval $command &
    fi
done

wait

