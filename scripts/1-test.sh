#!/usr/bin/env bash
set -euo pipefail
set -x

cd ${TRAVIS_BUILD_DIR}
pip3 install -r requirements.txt
cd ./src

export APPROOVA_DB_PATH="${TRAVIS_BUILD_DIR}/sqlite.db"
export APPROOVA_DOTENV_PATH="${TRAVIS_BUILD_DIR}/src/.env"

python3 bot.py
