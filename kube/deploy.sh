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

rm -rf deployment.yml
cp -r deployment.yml.template deployment.yml

if [[ "${TRAVIS_BRANCH}" == "master" && "${TRAVIS_PULL_REQUEST}" == "false" ]]; then
    COMMIT=${TRAVIS_TAG}
else
    COMMIT=${TRAVIS_COMMIT}
fi

sed -i -e "s|ENVIRONMENT|${ENV}|g" deployment.yml
sed -i -e "s|environment|${kube_env}|g" deployment.yml
sed -i -e "s|COMMIT|${COMMIT}|g" deployment.yml
sed -i -e 's|KUBE_CA_CERT|'"${KUBE_CA_CERT}"'|g' kubeconfig
sed -i -e 's|KUBE_ENDPOINT|'"${KUBE_ENDPOINT}"'|g' kubeconfig
sed -i -e 's|KUBE_ADMIN_CERT|'"${KUBE_ADMIN_CERT}"'|g' kubeconfig
sed -i -e 's|KUBE_ADMIN_KEY|'"${KUBE_ADMIN_KEY}"'|g' kubeconfig
chkErr


runDocker="docker run -v ${TRAVIS_BUILD_DIR}/kube:/kube bitnami/kubectl:latest"
chkErr
kubeFlags="--kubeconfig /kube/kubeconfig --insecure-skip-tls-verify=true"
kubectl="${runDocker} ${kubeFlags}"

${kubectl} delete secret approova-${kube_env}-discord
${kubectl} create secret generic approova-${kube_env}-discord --from-literal=username="discord" --from-literal=password="${APPROOVA_DISCORD_TOKEN}"
chkErr
${kubectl} apply -f /kube/deployment.yml
chkErr

if ! ${kubectl} rollout status deployment approova-${kube_env}; then
    echo "k8s failed to deploy!"
    ${kubectl} rollout undo deployment approova-${kube_env}
    ${kubectl} rollout status deployment approova-${kube_env}
    exit 1
fi
