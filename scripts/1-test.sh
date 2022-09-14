#!/usr/bin/env bash
set -euo pipefail
set -x

cd ${TRAVIS_BUILD_DIR}

go build -o ./bin/approova