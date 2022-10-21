#!/usr/bin/env bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")

if [ "${RUNNER_OS}" == "Windows" ]; then
  export KIND_OS="windows"
  export KIND_KUBECTL_BINARY="kubectl.exe"
  export SUDO=""
elif [ "${RUNNER_OS}" == "Linux" ]; then
  export KIND_OS="linux"
  export KIND_KUBECTL_BINARY="kubectl"
  export SUDO="sudo"
else
  echo "Error: Support for operating systems other than linux or windows is not currently supported"
  exit 1
fi

if [ "${RUNNER_ARCH}" == "X64" ]; then
  export KIND_ARCH="amd64"
elif [ "${RUNNER_ARCH}" == "ARM64" ] && [ "${KIND_OS}" == "linux" ]; then
  export KIND_ARCH="arm64"
elif [ "${RUNNER_ARCH}" == "ARM64" ] && [ "${KIND_OS}" == "windows" ]; then
  echo "Error: Kind is not available for ${KIND_OS} on ${RUNNER_ARCH}"
  exit 1
else
  echo "Error: Support for the os/architecture ${KIND_OS}/${RUNNER_ARCH} is not currently supported"
  exit 1
fi

main() {
    args_kind=()
    args_knative=()
    args_registry=()

    if [[ -n "${INPUT_VERSION:-}" ]]; then
        args_kind+=(--version "${INPUT_VERSION}")
    fi

    if [[ -n "${INPUT_CONFIG:-}" ]]; then
        args_kind+=(--config "${INPUT_CONFIG}")
    fi

    if [[ -n "${INPUT_NODE_IMAGE:-}" ]]; then
        args_kind+=(--node-image "${INPUT_NODE_IMAGE}")
    fi

    if [[ -n "${INPUT_CLUSTER_NAME:-}" ]]; then
        args_kind+=(--cluster-name "${INPUT_CLUSTER_NAME}")
    fi

    if [[ -n "${INPUT_WAIT:-}" ]]; then
        args_kind+=(--wait "${INPUT_WAIT}")
    fi

    if [[ -n "${INPUT_LOG_LEVEL:-}" ]]; then
        args_kind+=(--log-level "${INPUT_LOG_LEVEL}")
    fi

    if [[ -n "${INPUT_KUBECTL_VERSION:-}" ]]; then
        args_kind+=(--kubectl-version "${INPUT_KUBECTL_VERSION}")
    fi

    if [[ -n "${INPUT_KNATIVE_SERVING:-}" ]]; then
        args_knative+=(--knative-serving "${INPUT_KNATIVE_SERVING}")
    fi

    if [[ -n "${INPUT_KNATIVE_KOURIER:-}" ]]; then
        args_knative+=(--knative-kourier "${INPUT_KNATIVE_KOURIER}")
    fi

    if [[ -n "${INPUT_KNATIVE_EVENTING:-}" ]]; then
        args_knative+=(--knative-eventing "${INPUT_KNATIVE_EVENTING}")
    fi

    if [[ -n "${INPUT_REGISTRY_IMAGE:-}" ]]; then
        args_registry+=(--registry-image "${INPUT_REGISTRY_IMAGE}")
    fi

    if [[ -n "${INPUT_REGISTRY_NAME:-}" ]]; then
        args_registry+=(--registry-name "${INPUT_REGISTRY_NAME}")
    fi

    if [[ -n "${INPUT_REGISTRY_PORT:-}" ]]; then
        args_registry+=(--registry-port "${INPUT_REGISTRY_PORT}")
    fi

    if [[ -z "${INPUT_REGISTRY:-}" ]] || [[ "${INPUT_REGISTRY,,}" = "true" ]]; then
        "$SCRIPT_DIR/registry.sh" "${args_registry[@]}"

        if [[ -n "${INPUT_CONFIG:-}" ]]; then
            echo 'WARNING: when using the "config" option, you need to manually configure the registry in the provided configuration'
        else
            args_kind+=(--config "/etc/kind-registry/config.yaml")
        fi
    fi

    "$SCRIPT_DIR/kind.sh" "${args_kind[@]}"

    if [[ -z "${INPUT_REGISTRY:-}" ]] || [[ "${INPUT_REGISTRY,,}" = "true" ]]; then
        "$SCRIPT_DIR/registry.sh" "--document" "true" "${args[@]}"
    fi

    "$SCRIPT_DIR/knative.sh" "${args_knative[@]}"
}

main
