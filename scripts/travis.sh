#!/usr/bin/env bash
set -euo pipefail
set -x

cd ${TRAVIS_BUILD_DIR}/scripts

bash ${TRAVIS_BUILD_DIR}/scripts/travis-check_if_abort.sh
if [[ "${ABORT}" == "true" ]];
    exit 0
fi

if [[ "${LOCAL_BUILD}" != "1" ]]; then
    bash travis-bootstrap.sh
fi

if [[ "${SKIP_TEST}" != "1" ]]; then
    bash 1-test.sh
fi

if [[ "${TRAVIS_PULL_REQUEST}" == "false" && "${TRAVIS_BRANCH}" == "master" ]]; then
    export ENV=LIVE
elif [[ "${TRAVIS_PULL_REQUEST}" == "false" ]]; then
    export ENV=TEST
else 
    echo "Exiting early because I don't deploy pull requests to DockerHub"
    exit 0
fi

if [[ "${SKIP_BUILD}" != "1" ]]; then
    bash 2-build.sh
fi

if [[ "${SKIP_DEPLOY}" != "1" ]]; then
    bash 3-deploy-kube.sh
fi
