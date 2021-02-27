#!/usr/bin/env bash
set -euo pipefail
set -x

source ${TRAVIS_BUILD_DIR}/scripts/common.sh

commit=$(git rev-list -n 1 ${TRAVIS_TAG})

getState() { 
    state=$(curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/alex4108/approova/commits/${commit}/status)
}

# * Check the build passed

getState
while [[ ${state} != ""]]

# * Re-tag the container
dockerLogin
docker pull alex4108/approova:${commit}
docker tag alex4108/approova:${commit} alex4108/approova:${TRAVIS_TAG}
docker push alex4108/approova:${TRAVIS_TAG}

# * Deploy to kube (LIVE)
cd ${TRAVIS_BUILD_DIR}/scripts
bash 3-deploy-kube.sh

# * Publish github release
# (handled by travis-release-hooks.sh)