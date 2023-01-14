#!/bin/bash

echo "HTTP/1.1 200 OK"
printf '%s: ' Date
LANG=C TZ=GMT date '+%a, %d %b %Y %T %Z'
echo "Content-Length: 1920080"
echo "Content-Type: audio/x-wav"
echo
sox -n -r 8000 -t s16 - synth 60 sine 500 
