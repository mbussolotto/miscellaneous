#!/bin/bash


#Require SimpleHTTPServer (python2), install it using pip

REPO_ABS_PATH=$1
PORT_NUMBER=$2

CURRENT_FOLDER=$(pwd)
GIT_HIDE_FOLDER=".git"
POST_UPDATE_SAMPLE_FILE="hooks/post-update.sample hooks/post-update"
POST_UPDATE_FILE="hooks/post-update.sample hooks/post-update"

REPO_ABS_PATH=$1
PORT_NUMBER=$2
REPO_NAME=$(basename ${REPO_ABS_PATH})
SERVER_FOLDER=$(dirname ${REPO_ABS_PATH})

cd ${SERVER_FOLDER}/${REPO_NAME}/${GIT_HIDE_FOLDER}
git --bare update-server-info
if [ -f "${POST_UPDATE_SAMPLE_FILE}" ]; then
    mv ${POST_UPDATE_SAMPLE_FILE} ${POST_UPDATE_FILE}
fi

cd ${SERVER_FOLDER}
python -m SimpleHTTPServer ${PORT_NUMBER}
