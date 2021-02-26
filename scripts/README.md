You must be running on a linux based host to run the pipeline scripts.  
The host must be equipped with docker, qemu, and docker-buildx.  See .travis.yml for an example of what's needed in the host


If you want to test the travis.sh (build script) locally, set these variables

```
export TRAVIS_PULL_REQUEST="false"
export TRAVIS_BRANCH="kube"
export TRAVIS_BUILD_DIR="/root/of/project"
export DOCKER_USER="docker_username"
export DOCKER_PASS="docker_password"
export TRAVIS_COMMIT="testy"
```

If you want to test the kubernetes deployment pipeline, set these variables.
You must deploy a private volume matching the volumeMount's name as defined in `kube/deployment.yml`

```
export KUBE_CA_CERT=""
export KUBE_ADMIN_CERT=""
export KUBE_ADMIN_KEY=""
export KUBE_ENDPOINT=""
export nfs_path=""
export nfs_host=""
export BOT_TOKEN="discord-bot-token"
```
