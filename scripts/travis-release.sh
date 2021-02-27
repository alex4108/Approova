#!/usr/bin/env bash
set -euo pipefail

source ${TRAVIS_BUILD_DIR}/scripts/common.sh

commit=$(git rev-list ${TRAVIS_TAG} -n 1)

getState() { 
    builds=$(curl -s -H "Travis-API-Version: 3" -H "Authorization: token ${TRAVIS_API_TOKEN}" https://api.travis-ci.com/repo/15450713/builds)
    state=$(echo ${builds} | jq -r --arg COMMIT "${commit}" ' [ .builds | map({ "id": .id, "state": .state, "commit": .commit.sha, "branch": .branch.name, "ts": .updated_at }) | sort_by(.ts)[] | select(.commit==$COMMIT and .branch=="master") ] | .[].state')
    echo "Waiting for ${commit} build to finish :: ${state}"
}

# * Check the build passed

removeTag() { 
    freshClone
    gitConfig
    git tag -d ${TRAVIS_TAG}
    git push --delete origin ${TRAVIS_TAG}
}

getState
while true; do
    if [[ "${state}" == "success" || "${state}" == "passed" ]]; then
        echo "Build success"
        break
    elif [[ "${state}" == "failed" || "${state}" == "canceled" || "${state}" == "errored" ]]; then
        echo "Build failed"
        removeTag
        exit 1
    else
        sleep 5
        getState
    fi
done

echo "Ready to go!"

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