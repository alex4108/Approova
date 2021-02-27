#!/usr/bin/env bash

dockerLogin() { 
    docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}
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
