#!/usr/bin/env bash

dockerLogin() { 
    docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}
}