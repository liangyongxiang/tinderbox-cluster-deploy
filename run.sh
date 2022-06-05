#!/bin/bash

set -x

TINDERBOX_CLUSTER="${TINDERBOX_CLUSTER:-tinderbox-cluster}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# python env
if command -v deactivate; then
    deactivate
fi
source sandbox/bin/activate

cd "${TINDERBOX_CLUSTER}"

if ! buildbot start; then
    less twistd.log
fi
