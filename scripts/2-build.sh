#!/usr/bin/env bash
set -euo pipefail

DOCKER_PLATFORMS="linux/amd64,linux/arm/v7,linux/arm64/v8"

cd ${TRAVIS_BUILD_DIR}

DOCKER_TAG="${DOCKER_USER}/approova:${TRAVIS_COMMIT}"

if [[ "${SKIP_PUSH}" != "1" ]]; then
    docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}
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
    docker tag ${DOCKER_TAG} "${DOCKER_USER}/approova:latest"
    version=$(cat ${TRAVIS_BUILD_DIR}/VERSION)
    docker tag ${DOCKER_TAG} "${DOCKER_USER}/approova:${version}"
    docker push "${DOCKER_USER}/approova:latest"
    docker push "${DOCKER_USER}/approova:${version}"
fi
