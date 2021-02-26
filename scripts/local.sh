#!/usr/bin/env bash

set -euo pipefail

export TRAVIS_PULL_REQUEST="false"
export TRAVIS_BRANCH="local-$(date +%s)"
export LOCAL_BUILD="0"
export TRAVIS_BUILD_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )/../"
export DOCKER_USER="docker_username" # SET THIS
export DOCKER_PASS="docker_password" # SET THIS
export TRAVIS_COMMIT="${TRAVIS_BRANCH}"
export APPROOVA_DOTENV_PATH="${TRAVIS_BUILD_DIR}/src/.env"
export APPROOVA_DB_PATH="${TRAVIS_BUILD_DIR}/sqlite.db"
export KUBE_CA_CERT="" # SET THIS
export KUBE_ADMIN_CERT="" # SET THIS
export KUBE_ADMIN_KEY="" # SET THIS
export KUBE_ENDPOINT="" # SET THIS
export DOCKER_EMAIL="" # email of dockerhub account
export APPROOVA_DISCORD_TOKEN="discord-bot-token" # Your Discord bot token
export APPROOVA_DOTENV_PATH="${TRAVIS_BUILD_DIR}/src/.env"
export APPROOVA_DB_PATH="${TRAVIS_BUILD_DIR}/sqlite.db"
export SKIP_PUSH="0" # Set this if you want to skip pushing to dockerhub
export SKIP_KUBE="0" # Set this if you want to skip deploying to kubernetes
export ONLY_LINUX="1" # Set this if you don't want to build arm architectures
export SKIP_TEST="0" # Set this to skip Travis' test step
export SKIP_BUILD="0" # Set this to skip Travis' build step
export SKIP_DEPLOY="0" # Set this to skip Travis' deploy step
export GITHUB_PAT="" # Github personal access token for relases
export TRAVIS="1"
export LOCAL_DEPLOY="0" # Set to 1 to run github releases step

cd ${TRAVIS_BUILD_DIR}/scripts
bash travis.sh


if [[ "${LOCAL_DEPLOY}" == "1" ]]; then
    bash travis-deploy.sh BEFORE
    # Travis would upload the deployment now
    # Then...
    bash travis-deploy.sh AFTER
fi

