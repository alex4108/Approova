#!/usr/bin/env bash
set -euo pipefail
set -x

cd ${TRAVIS_BUILD_DIR}/scripts

ABORT=$(bash ${TRAVIS_BUILD_DIR}/scripts/travis-check_if_abort.sh)
if [[ "${ABORT}" == "true" ]]; then
    exit 0
fi

if [[ "${LOCAL_BUILD}" != "1" ]]; then
    bash travis-bootstrap.sh
fi

# If this is tagged, run travis-release.sh
if [[ "${TRAVIS_TAG}" == "" ]]; then
    export ENV=TEST
    bash travis-commit.sh
else
    export ENV=LIVE
    bash travis-release.sh
fi