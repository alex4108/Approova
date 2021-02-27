#!/usr/bin/env bash

# For every commit that is not tagged:
# * Test the code (1-test.sh)
# * Build the container (2-build.sh)
# * Deploy to kube (3-deploy.sh)

if [[ "${SKIP_TEST}" != "1" ]]; then
    bash 1-test.sh
fi

if [[ "${TRAVIS_PULL_REQUEST}" != "false" ]]; then
    echo "Exiting early because I don't deploy pull requests to DockerHub"
    exit 0
fi

if [[ "${SKIP_BUILD}" != "1" ]]; then
    bash 2-build.sh
fi

if [[ "${SKIP_DEPLOY}" != "1" ]]; then
    bash 3-deploy-kube.sh
fi

