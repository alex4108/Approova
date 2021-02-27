#!/usr/bin/env bash
set -euo pipefail
set -x

source ${TRAVIS_BUILD_DIR}/common.sh
DOCKER_PLATFORMS="linux/amd64,linux/arm/v7,linux/arm64/v8"

cd ${TRAVIS_BUILD_DIR}

DOCKER_TAG="${DOCKER_USER}/approova:${TRAVIS_COMMIT}"

if [[ "${SKIP_PUSH}" != "1" ]]; then
    dockerLogin
fi

docker buildx create --use
if [[ "${SKIP_PUSH}" == "1" && "${ONLY_LINUX}" != "1" ]]; then
    docker buildx build --platform ${DOCKER_PLATFORMS} -t ${DOCKER_TAG} .
elif [[ "${ONLY_LINUX}" != "1" ]]; then
    docker buildx build --platform ${DOCKER_PLATFORMS} -t ${DOCKER_TAG} . --push
else 
    docker build -t ${DOCKER_TAG} .
    docker push ${DOCKER_TAG}
fi

if [[ "${TRAVIS_BRANCH}" == "master" && "${SKIP_PUSH}" != "1" ]]; then
    version=$(cat ${TRAVIS_BUILD_DIR}/VERSION)
    docker buildx build --platform ${DOCKER_PLATFORMS} -t "alex4108/approova:latest" . --push
    docker buildx build --platform ${DOCKER_PLATFORMS} -t "alex4108/approova:${version}" . --push
fi
