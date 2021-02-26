#!/usr/bin/env bash

set -euo pipefail
set -x

STATE=$1
version=$(cat ${TRAVIS_BUILD_DIR}/VERSION)

freshClone() { 
    mkdir -p /tmp
    cd /tmp
    git clone git@github.com:alex4108/Approova.git
}

# Configures git for GPG Signing
gitConfig() { 
    gpg --import /tmp/travis.gpg
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    mv /tmp/id_rsa ~/.ssh/id_rsa
    chmod 400 ~/.ssh/id_rsa
    git config --local user.name "Alex Schittko"
    git config --local user.email "alex4108@live.com"
    git config --global user.signingkey DFF8E003A6969029
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
    git push tags
}

if [[ "${STATE}" == "BEFORE" ]]; then # Tag the release
    gitConfig
    freshClone
    cd /tmp/Approova
    export TRAVIS_TAG="${version}"
    git checkout master
    git tag -s ${version} -m "Release ${version}"
    git push origin ${version}

elif [[ "${STATE}" == "AFTER" ]]; then
    ## Update the release w/ CHANGELOG.md contents
    last_release_id=$(curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/alex4108/approova/releases | jq -r '.[0].id')
    changelog=$(cat ${TRAVIS_BUILD_DIR}/CHANGELOG.md | sed "0,/RELEASE_VERSION/{s/RELEASE_VERSION/${version}/}")

    curl -X PATCH https://api.github.com/repos/alex4108/approova/releases/${last_release_id} -u alex4108:${GITHUB_PAT} -d "{\"name\": \"v${version}\", \"body\": \"${changelog}\"}"
    # curl -X PATCH https://api.github.com/repos/alex4108/approova/releases/${last_release_id} -u alex4108:${GITHUB_PAT} -d "{\"draft\": \"false\"}"

    cd /tmp/Approova/
    bumpVersion
fi
