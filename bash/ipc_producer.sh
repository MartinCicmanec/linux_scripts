#!/bin/bash

# Example file for Inter Process Communication producer
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
    rm -f "${STORAGE_FILE}"

    while true; do
        for (( i=1; i<=10; i++ )); do
            uid="$(uuidgen)"
            echo "${uid}"
            echo "${uid}" >> "${STORAGE_FILE}"
        done
        sleep 5s
    done
elif (( $1 == 2 )); then
    echo "Similar as mode 1, but use /dev/shm/storage"
    sleep 1s
elif (( $1 == 3 )); then
    # Unnamed pipe example
    for (( i=1; i<=10; i++ )); do
        uid="$(uuidgen)"
        echo "${uid}"
    done
elif (( $1 == 4 )); then
    # Named pipe example
    if [[ ! -p ${PIPE} ]]; then mkfifo ${PIPE}; fi

    while true; do
        for (( i=1; i<=10; i++ )); do
            uid="$(uuidgen)"
            echo "${uid}"
            echo "${uid}" > "${PIPE}"
            sleep 1s
        done
    done
elif (( $1 == 5 )); then
    # Socket example, requires netcat
    rm -f "${SOCKET}"

    while true; do
        uuidgen;
        sleep 1s;
    done \
    | tee /dev/tty | nc -lU "${SOCKET}"
fi