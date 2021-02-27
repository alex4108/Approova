#!/usr/bin/env bash

if [[ "${TRAVIS_COMMIT_MESSAGE}" == "(CI)"* ]]; then
    echo "true"
else
    echo "false"
fi