#!/bin/bash

LOCAL_PROJECT="$HOME/Projects/tesseract"
EC2_PROJECT="~/tesseract"
DB="tesseract.db"

PEM="$HOME/gnome.pem"
EC2="ubuntu@ec2-54-85-142-145.compute-1.amazonaws.com"

SCREEN_SESSION="tesseract"

if [ $USER == skishore ]
  then
    echo "Pushing to github..."
    git push
    echo "Copying tesseract.db..."
    scp -i $PEM $LOCAL_PROJECT/$DB $EC2:$EC2_PROJECT/$DB
    ssh -i $PEM $EC2 "cd $EC2_PROJECT; ./deploy.sh"
  else
    echo "Deploying on EC2..."
    git fetch
    git reset --hard origin/master
    ./kick.sh
fi
