#!/bin/bash

trap sig_handler SIGUSR1

function sig_handler() {
    echo "Signal caught!"
}


while true; do
    # Run with './sig_handler.sh' and stop with 'killall -e -TERM sig_handler.sh'
    echo "Waiting"
    sleep 3s
done