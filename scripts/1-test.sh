#!/usr/bin/env bash
set -euo pipefail

cd ${TRAVIS_BUILD_DIR}
pip3 install -r requirements.txt
cd ./src
python3 bot.py