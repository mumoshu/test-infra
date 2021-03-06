#!/bin/bash
# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

for i in {1..10}; do
  echo 'WARNING: pull-kops-e2e-kubernetes-aws.sh is deprecated, migrate to scenarios/kubernetes_e2e.py'
done

readonly testinfra="$(dirname "${0}")/.."

export GCS_LOCATION="${GCS_LOCATION:-gs://kops-ci/pulls/${JOB_NAME}}"
export KOPS_VERSION="pull-$(git describe --always)"
export KOPS_BASE_URL="${GCS_LOCATION/gs:\/\//https:\/\/storage.googleapis.com\/}/${KOPS_VERSION}"
make gcs-publish-ci "VERSION=${KOPS_VERSION}"

# Using latest stable k8s release
export JENKINS_PUBLISHED_VERSION=release/stable
export KUBERNETES_RELEASE=$(gsutil cat "gs://kubernetes-release/${JENKINS_PUBLISHED_VERSION}.txt")

export KUBERNETES_PROVIDER="kops-aws"

if [[ -z "${KOPS_ZONES:-}" ]]; then
  # Pick a random US AZ. (We have high regional quotas in
  # us-{east,west}-{1,2})
  #
  # TODO(zmerlynn): Re-add us-east-2
  case $((RANDOM % 6)) in
    0) export KOPS_ZONES=us-west-1a ;;
    1) export KOPS_ZONES=us-west-1c ;;
    2) export KOPS_ZONES=us-west-2a ;;
    3) export KOPS_ZONES=us-west-2b ;;
    4) export KOPS_ZONES=us-east-1a ;;
    5) export KOPS_ZONES=us-east-1d ;;
    6) export KOPS_ZONES=us-east-2a ;;
    7) export KOPS_ZONES=us-east-2b ;;
  esac
  export KOPS_REGIONS=${KOPS_ZONES::-1}
fi

export KOPS_STATE_STORE="${KOPS_STATE_STORE:-s3://k8s-kops-jenkins/}"
export KOPS_CLUSTER_DOMAIN="${KOPS_CLUSTER_DOMAIN:-test-aws.k8s.io}"
export E2E_NAME="aws-kops-${NODE_NAME}-${EXECUTOR_NUMBER:-0}"
export E2E_OPT="${E2E_OPT:-}\
  --kops-cluster ${E2E_NAME}.${KOPS_CLUSTER_DOMAIN}\
  --kops-zones ${KOPS_ZONES}\
  --kops-kubernetes-version ${KUBERNETES_RELEASE}\
  --kops-nodes 4\
  --kops-state ${KOPS_STATE_STORE}"
export E2E_MIN_STARTUP_PODS="1"

export AWS_CONFIG_FILE="/workspace/.aws/credentials"
export AWS_SHARED_CREDENTIALS_FILE="/workspace/.aws/credentials"
export KUBE_SSH_USER=admin
export LOG_DUMP_USE_KUBECTL=yes
export LOG_DUMP_SSH_KEY=/workspace/.ssh/kube_aws_rsa
export LOG_DUMP_SSH_USER=admin
export LOG_DUMP_SAVE_LOGS="cloud-init-output"
export LOG_DUMP_SAVE_SERVICES="protokube"

# Flake detection. Individual tests get a second chance to pass.
export GINKGO_TOLERATE_FLAKES="y"
export GINKGO_PARALLEL="y"
# This list should match the list in ci-kubernetes-e2e-kops-aws.
export GINKGO_TEST_ARGS='--ginkgo.skip=\[Slow\]|\[Serial\]|\[Disruptive\]|\[Flaky\]|\[Feature:.+\]|\[HPA\]|Dashboard|Services.*functioning.*NodePort'
# GINKGO_PARALLEL_NODES should match ci-kubernetes-e2e-kops-aws.
export GINKGO_PARALLEL_NODES="30"

# Assume we're upping, testing, and downing a cluster
export E2E_UP="true"
export E2E_TEST="true"
export E2E_DOWN="true"

# Skip gcloud update checking
export CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=true

# Get golang into our PATH so we can run e2e.go
export PATH=${PATH}:/usr/local/go/bin

export KUBE_E2E_RUNNER="/workspace/kops-e2e-runner.sh"
readonly runner="${testinfra}/jenkins/dockerized-e2e-runner.sh"
export DOCKER_TIMEOUT="75m"
export KUBEKINS_TIMEOUT="55m"
"${runner}"
