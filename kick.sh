#!/bin/bash

SCREEN_SESSION="tesseract"

coffee -o static/javascript/ -c coffee
sass --update scss:static/css

# Kill and reboot the screened server.
pid=$(screen -list | grep $SCREEN_SESSION | cut -d '.' -f 1 | bc)
if [ -n "$pid" ]; then
  screen -X -S $pid quit
fi
screen -S $SCREEN_SESSION -d -m python server.py
echo "Done!"
