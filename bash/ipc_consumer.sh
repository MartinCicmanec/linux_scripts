#!/bin/bash

# Example file for Inter Process Communication consumer
# producer.sh

STORAGE_FILE="./storage"
PIPE="pipe.fifo"
SOCKET="/var/tmp/ipc.sock"

if [ $# -lt 1 ]; then
    echo $#
    echo 1>&2 "$0: Missing mode argument, using dault mode 1."
    exit 2
fi

if (( $1 == 1 )); then

    while true; do
        while IFS= read -r line; do
            echo "${line}"
        done < "${STORAGE_FILE}"
        sleep 1s
    done
elif (( $1 == 2 )); then
    echo "Similar as mode 1, but use /dev/shm/storage"
    sleep 1s
elif (( $1 == 3 )); then
    # Unnamed pipe example
    echo "Consumer data:"
    echo "--------------"

    if [ -t 0 ]; then
        data="$*"
    else
        data=$(cat)
    fi
    echo "${data}"
elif (( $1 == 4 )); then
    # Named pipe example
    if [[ ! -p ${PIPE} ]]; then mkfifo ${PIPE}; fi

    while true; do
        if read line < "${PIPE}"; then
            echo "${line}"
        fi
    done
elif (( $1 == 5 )); then
    # Socket example, requires netcat
    nc -U "${SOCKET}"
fi