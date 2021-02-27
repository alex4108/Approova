#!/usr/bin/env bash


set -euo pipefail
set -x

ABORT=$(bash ${TRAVIS_BUILD_DIR}/scripts/travis-check_if_abort.sh)
if [[ "${ABORT}" == "true" ]]; then
    exit 0
fi

STATE=$1
version=${TRAVIS_TAG}

source ${TRAVIS_BUILD_DIR}/scripts/common.sh

# Resets the changelog
resetChangelog() { 
    freshClone
    echo -e "## Breaking Changes\n\n*\n\n## Bugs\n\n*\n\n## Improvements\n\n*\n""" > CHANGELOG.md
    git add CHANGELOG.md
    git commit -S -m "(CI) Update release version"
    git push origin
    cd ${OLD_PWD}
}

# Updates docker-compose.yml before releasing, to match the new version number
updateDockerCompose() {
    freshClone
    sed -i -e "s|image: alex4108/approova:.*|image: alex4108/approova:${version}|g" docker-compose.yml
    git add docker-compose.yml
    git commit -S -m "(CI) Update release version"
    git push origin
    cd ${OLD_PWD}
}

# Reset to delete any artifacts leftover from build
resetRepo() { 
    cd ${TRAVIS_BUILD_DIR}
    git reset --hard
}

# Gets the release ID associated with this release from GitHub
getReleaseId() { 
    trying="1"
    max_tries="10"
    sleep="2"
    try="1"
    while [[ "${trying}" == "1" ]]; do
        release_id=$(curl -H "Accept: application/vnd.github.v3+json" -u alex4108:${GITHUB_PAT} https://api.github.com/repos/alex4108/Approova/releases | jq -r ".[] | select(.tag_name == \"${version}\").id")
        if [[ "${release_id}" == "null" || "${release_id}" == "" ]]; then
            echo "Failed!"
            echo "Sleeping ${sleep} seconds"
            sleep ${sleep}
            sleep=$((${sleep} * ${sleep}))
            try=$((${try} + 1))
        else
            trying=0
        fi

        if [[ "${try}" == "${max_tries}" ]]; then
            echo "You've failed me for the last time!"
            exit 1
        fi
    done
}



# Tag the release
# Fix docker compose
if [[ "${STATE}" == "BEFORE" ]]; then 
    gitConfig
    resetRepo
    updateDockerCompose

# Update the release in Github
# bump develop's version
elif [[ "${STATE}" == "AFTER" ]]; then 
    gitConfig
    getReleaseId
    sed -i ':a;N;$!ba;s|\n|\\r\\n|g' ${TRAVIS_BUILD_DIR}/CHANGELOG.md
    sed -i 's|"|\\"|g' ${TRAVIS_BUILD_DIR}/CHANGELOG.md
    curl -X PATCH https://api.github.com/repos/alex4108/Approova/releases/${release_id} -u alex4108:${GITHUB_PAT} -d "{\"tag_name\": \"${version}\", \"name\": \"v${version}\", \"body\": \"$(cat ${TRAVIS_BUILD_DIR}/CHANGELOG.md)\", \"draft\": \"false\"}"
    resetChangelog
fi

