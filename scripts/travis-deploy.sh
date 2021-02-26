#!/usr/bin/env bash

set -euo pipefail

STATE=$1
version=$(cat ${TRAVIS_BUILD_DIR}/VERSION)


# Configures git for GPG Signing
gitConfig() { 
    gpg --import ${TRAVIS_BUILD_DIR}/travis.gpg
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    mv ${TRAVIS_BUILD_DIR}/id_rsa ~/.ssh/id_rsa
    chmod 400 ~/.ssh/id_rsa
    git config --local user.name "Alex Schittko"
    git config --local user.email "alex4108@live.com"
    git config --global user.signingkey 3AA5C34371567BD2
    echo -e "Host github.com\n    StrictHostKeyChecking no" > ~/.ssh/config
}

# Bumps the version
bumpVersion() { 
    echo -e "# Release RELEASE_VERSION\n\n## Breaking Changes\n\n*\n\n## Bugs\n\n*\n\n## Improvements\n\n*\n""" > CHANGELOG.md
    next_version_minor="$(( $(cat ${TRAVIS_BUILD_DIR}/VERSION | cut -d. -f3) + 1 ))"
    next_version="$(cat ${TRAVIS_BUILD_DIR}/VERSION | cut -d. -f1).$(cat ${TRAVIS_BUILD_DIR}/VERSION | cut -d. -f2).${next_version_minor}" > VERSION
    git checkout develop
    rm -rf VERSION
    rm -rf CHANGELOG.md
    cp ${TRAVIS_BUILD_DIR}/CHANGELOG.md ./CHANGELOG.md
    cp ${TRAVIS_BUILD_DIR}/VERSION ./VERSION
    git add CHANGELOG.md
    git add VERSION
    git commit -S -m "Reset VERSION & CHANGELOG.md"
    git push
}

# Resets files between releases
reset() { 
    OLDPWD=$(pwd)
    mkdir /tmp/
    cd /tmp/
    git clone git@github.com:alex4108/approova.git
    cd approova
    bumpVersion
    cd ${OLDPWD}
}


if [[ "${STATE}" == "BEFORE" ]]; then # Tag the release
    gitConfig
    export TRAVIS_TAG="${version}"
    git tag -s ${version} -m "Release ${version}"
    mkdir -p ${TRAVIS_BUILD_DIR}/.ssh
    chmod 700 ${TRAVIS_BUILD_DIR}/.ssh
    mv ${TRAVIS_BUILD_DIR}id_rsa ${TRAVIS_BUILD_DIR}/.ssh/id_rsa
    chmod 400 ${TRAVIS_BUILD_DIR}/.ssh/id_rsa
    git push

elif [[ "${STATE}" == "AFTER" ]]; then
    ## Update the release w/ CHANGELOD.md contents
    last_release_id=$(curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/alex4108/approova/releases | jq -r '.[0].id')
    changelog=$(cat ${TRAVIS_BUILD_DIR}/CHANGELOG.md | sed "0,/RELEASE_VERSION/{s/RELEASE_VERSION/${version}/}")

    curl -X PATCH https://api.github.com/repos/alex4108/approova/releases/${last_release_id} -u alex4108:${GITHUB_PAT} -d "{\"name\": \"v${version}\", \"body\": \"${changelog}\"}"
    # curl -X PATCH https://api.github.com/repos/alex4108/approova/releases/${last_release_id} -u alex4108:${GITHUB_PAT} -d "{\"draft\": \"false\"}"

    reset
fi
