#!/usr/bin/env bash

FILE=./docker-build/.env

if [[ -f "$FILE" ]]; then
  echo "$FILE exists and contains: "
  # Show env vars
  grep -v '^#' "$FILE"
  echo
  # Export env vars
  set -o allexport
  source "$FILE"
  set +o allexport
fi

project_name=${PROJECT_NAME:-invokeai}
volumename=${VOLUMENAME:-${project_name}_data}
arch=${ARCH:-x86_64}
platform=${PLATFORM:-Linux/${arch}}
invokeai_tag=${INVOKEAI_TAG:-${project_name}-${arch}}

export project_name
export volumename
export arch
export platform
export invokeai_tag
