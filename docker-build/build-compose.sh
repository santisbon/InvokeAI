#!/usr/bin/env bash
set -e
# IMPORTANT: You need to have a token on huggingface.co to be able to download the checkpoint.

source ./docker-build/env.sh || echo "please run from repository root" || exit 1

invokeai_conda_version=${INVOKEAI_CONDA_VERSION:-py39_4.12.0-${platform/\//-}}
invokeai_conda_prefix=${INVOKEAI_CONDA_PREFIX:-\/opt\/conda}
invokeai_conda_env_file=${INVOKEAI_CONDA_ENV_FILE:-environment-lin-cuda.yml}
invokeai_git=${INVOKEAI_GIT:-invoke-ai/InvokeAI}
invokeai_branch=${INVOKEAI_BRANCH:-main}
huggingface_token=${HUGGINGFACE_TOKEN?}

# print the settings
echo "You are using these values:"
echo -e "project_name:\t\t ${project_name}"
echo -e "volumename:\t\t ${volumename}"
echo -e "arch:\t\t\t ${arch}"
echo -e "platform:\t\t ${platform}"
echo -e "invokeai_conda_version:\t ${invokeai_conda_version}"
echo -e "invokeai_conda_prefix:\t ${invokeai_conda_prefix}"
echo -e "invokeai_conda_env_file: ${invokeai_conda_env_file}"
echo -e "invokeai_git:\t\t ${invokeai_git}"
echo -e "invokeai_tag:\t\t ${invokeai_tag}\n"
