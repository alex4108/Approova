#!/usr/bin/env bash


set -euo pipefail
set -x

ABORT=$(bash ${TRAVIS_BUILD_DIR}/scripts/travis-check_if_abort.sh)
if [[ "${ABORT}" == "true" ]]; then
    exit 0
fi

STATE=$1
version=${TRAVIS_TAG}

# Resets the changelog
resetChangelog() { 
    echo -e "## Breaking Changes\n\n*\n\n## Bugs\n\n*\n\n## Improvements\n\n*\n""" > CHANGELOG.md
    git add CHANGELOG.md
    git commit -S -m "(CI) Update release version"
    git push origin
}

# Updates docker-compose.yml before releasing, to match the new version number
updateDockerCompose() {
    sed -i -e "s|image: alex4108/approova:.*|image: alex4108/approova:${version}|g" docker-compose.yml
    git add docker-compose.yml
    git commit -S -m "(CI) Update release version"
    git push origin
}

# Reset to delete any artifacts leftover from build
resetRepo() { 
    cd ${TRAVIS_BUILD_DIR}
    git reset --hard
}

# Makes a fresh clone of the repo
freshClone() { 
    OLD_PWD=$(pwd)
    ts=$(date +%s)
    mkdir -p /tmp/
    mkdir -p /tmp/${ts}
    cd /tmp/${ts}
    git clone git@github.com:alex4108/Approova.git
    cd /tmp/${ts}/Approova
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

# Configures git for GPG Signing & SSH Authentication
gitConfig() { 
    gpg --import /tmp/travis.gpg
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    /bin/cp -rf /tmp/id_rsa ~/.ssh/id_rsa
    chmod 400 ~/.ssh/id_rsa
    git config --global user.name "Alex Schittko"
    git config --global user.email "alex4108@live.com"
    git config --global user.signingkey DFF8E003A6969029
    echo -e "Host github.com\n    StrictHostKeyChecking no" > ~/.ssh/config
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
    curl -X PATCH https://api.github.com/repos/alex4108/Approova/releases/${release_id} -u alex4108:${GITHUB_PAT} -d "{\"tag_name\": \"${version}\", \"name\": \"v${version}\", \"body\": \"$(cat ${TRAVIS_BUILD_DIR}/CHANGELOG.md)\"}"
    curl -X PATCH https://api.github.com/repos/alex4108/Approova/releases/${release_id} -u alex4108:${GITHUB_PAT} -d "{\"draft\": \"false\"}"
    resetChangelog
fi

