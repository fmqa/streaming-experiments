#!/bin/bash

echo "HTTP/1.1 200 OK"
printf '%s: ' Date
LANG=C TZ=GMT date '+%a, %d %b %Y %T %Z'
echo "Content-Length: 960000"
echo "Content-Type: audio/l16; rate=8000; channels=1"
echo
sox -n -r 8000 -t s16 - synth 60 sine 500 | pv -L 1000
