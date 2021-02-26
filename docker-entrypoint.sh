#!/usr/bin/env bash

apt-get update && apt-get install -y lsb-release && apt-get clean all
lsb_release -a
cd /app
pip3 install -r requirements.txt
python3 bot.py