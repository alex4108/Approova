#!/usr/bin/env bash

if [[ "${TRAVIS_COMMIT_MESSAGE}" == "(CI)"* ]]; then
    echo "Aborting as this was an automated commit."
    exit 0
fi