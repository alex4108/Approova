#!/usr/bin/env bash
set -euo pipefail
set -x

cd ${TRAVIS_BUILD_DIR}/kube

if [[ "${SKIP_KUBE}" == "1" ]]; then
    echo "Skipping deploy"
else
    bash deploy.sh
fi