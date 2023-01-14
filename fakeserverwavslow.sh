#!/bin/bash

echo "HTTP/1.1 200 OK"
printf '%s: ' Date
LANG=C TZ=GMT date '+%a, %d %b %Y %T %Z'
echo "Content-Length: 1920080"
echo "Content-Type: audio/x-wav"
echo
WAVFILE=$(mktemp)
trap 'rm -f -- $WAVFILE' INT TERM HUP EXIT
sox -n -r 8000 -t wav $WAVFILE synth 60 sine 500
cat $WAVFILE | pv -L ${1:-64000}
