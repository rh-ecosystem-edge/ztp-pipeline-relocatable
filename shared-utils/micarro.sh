#!/bin/bash


export WORKDIR=$GITHUB_WORKSPACE
echo $WORKDIR
. ${WORKDIR}/${SHARED_DIR}common.sh

env
