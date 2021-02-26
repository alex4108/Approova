# Build Scripts

1. `1-test.sh`: Installs the requirements via `pip` locally, and proceeds to test the bot.  Currently, this only checks the main `bot.py` starts.  
1. `2-build.sh`: Builds the docker container(s) for the project and pushes them to DockerHub.
1. `3-deploy-kube.sh`: Deploys the update to a kubernetes cluster. 

## Testing

The test only installs requirements via `pip` and runs the bot with `python3 bot.py`.

The bot will exit because the `TRAVIS` environment variable will be set.

This effectively performs a lint against `bot.py`, but doesn't provide for unit testing.

## Build the Container

In Travis-CI, the bot will be built using `docker buildx`.  You can see how to set up `buildx` yourself in `.travis.yml`.

Upon successful build, the container will be pushed to DockerHub.

## Kubernetes

I included my kubernetes templates for your use, if you wish to use them.

## Running Build Scripts locally

Use `scripts/local.sh`

Be sure to modify the environment variables as noted in the script.

### Test & Build

**You must be running on a linux based host to run the pipeline scripts.**
__The host must be equipped with docker, qemu, and docker-buildx.  See .travis.yml for an example of what's needed in the host__

You can set this environment variable to only build the `linux/amd64` arch: `export ONLY_LINUX="1'`
You can set this environment variable to skip docker's push step: `export SKIP_PUSH="1'`
You can set this environment variable to skip the kubernetes deployment: `export SKIP_KUBE="1"`

### Deploy to Kubernetes

You must deploy two persistent volumes, named `approova-test-pv` and `approova-live-pv`.  See `kube/pv.yml` for an example (using NFS)

The PVC only stores the sqlite database used by the bot.

If you want to test the kubernetes deployment script, set these variables (and those above) and run `cd kube && bash deploy.sh`

