#!/usr/bin/env bash
set -euo pipefail
set -x

cd ${TRAVIS_BUILD_DIR}/scripts

bash 1-test.sh

if [[ "${TRAVIS_PULL_REQUEST}" == "false" && "${TRAVIS_BRANCH}" == "master" ]]; then
    export ENV=LIVE
elif [[ "${TRAVIS_PULL_REQUEST}" == "false" && "${TRAVIS_BRANCH}" == "develop" ]]; then
    export ENV=TEST
else 
    echo "Exiting early because I don't deploy pull requests to DockerHub"
    exit 0
fi

bash 2-build.sh

bash 3-deploy-kube.sh