#!/usr/bin/env bash
set -u
set -x

chkErr() { 
    if [[ "$?" -gt "0" ]]; then
        echo "Error occured!"
        exit 1
    fi
}

K8S_DEPLOYMENT_NAME="approova-${ENV}"
chkErr
kube_env=$(echo "${ENV}" | awk '{print tolower($0)}')
chkErr
runDocker="docker run -v ${TRAVIS_BUILD_DIR}/kube:/kube bitnami/kubectl:latest"
chkErr

sed -i -e "s|ENVIRONMENT|${ENV}|g" deployment.yml
sed -i -e "s|environment|${kube_env}|g" deployment.yml
sed -i -e "s|COMMIT|${TRAVIS_COMMIT}|g" deployment.yml
sed -i -e "s|BOT-TOKEN|${BOT_TOKEN}|g" deployment.yml
sed -i -e 's|DEPLOYMENT_NAME|'"${K8S_DEPLOYMENT_NAME}"'|g' deployment.yml
sed -i -e 's|DOCKER_USER|'"${DOCKER_USER}"'|g' deployment.yml
sed -i -e 's|KUBE_CA_CERT|'"${KUBE_CA_CERT}"'|g' kubeconfig
sed -i -e 's|KUBE_ENDPOINT|'"${KUBE_ENDPOINT}"'|g' kubeconfig
sed -i -e 's|KUBE_ADMIN_CERT|'"${KUBE_ADMIN_CERT}"'|g' kubeconfig
sed -i -e 's|KUBE_ADMIN_KEY|'"${KUBE_ADMIN_KEY}"'|g' kubeconfig
chkErr

kubeFlags="--kubeconfig /kube/kubeconfig --insecure-skip-tls-verify=true"

${runDocker} ${kubeFlags} delete secret approova-${kube_env}-docker
${runDocker} ${kubeFlags} delete secret approova-${kube_env}-discord
${runDocker} ${kubeFlags} create secret docker-registry approova-${kube_env}-docker --docker-server=https://index.docker.io/v2/ --docker-username=${DOCKER_USER} --docker-password=\"${DOCKER_PASS}\" --docker-email=${DOCKER_EMAIL} 
chkErr
${runDocker} ${kubeFlags} create secret generic approova-${kube_env}-discord --from-literal=username=\"discord\" --from-literal=password=\"${BOT_TOKEN}\"
chkErr
${runDocker} ${kubeFlags} apply -f /kube/deployment.yml
chkErr

