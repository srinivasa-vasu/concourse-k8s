#!/bin/bash
set -e

initialize() {
  echo "Initializing kubectl..."
  payload=$1
  source=$2
  # Setup kubectl
  cluster_url=$(jq -r '.source.cluster_url // ""' < $payload)
  if [ -z "$cluster_url" ]; then
    echo "invalid payload (missing cluster_url)"
    exit 1
  fi
  if [[ "$cluster_url" =~ https.* ]]; then

    cluster_ca=$(jq -r '.source.cluster_ca // ""' < $payload)
    admin_key=$(jq -r '.source.admin_key // ""' < $payload)
    admin_cert=$(jq -r '.source.admin_cert // ""' < $payload)
    #token=$(jq -r '.source.token // ""' < $payload)
    #token_path=$(jq -r '.params.token_path // ""' < $payload)
    admin_user=$(jq -r '.source.admin_user // "admin"' < $payload)
    admin_token=$(jq -r '.source.admin_token // ""' < $payload)

    if [ -z "$admin_user" ] || [ -z "$admin_token" ]; then
      if [ -z "$admin_key" ] || [ -z "$admin_cert" ]; then
        echo "Missing creds info: Either provide (admin_user and admin_token) or (admin_key and admin_cert)"
        exit 1
      fi
    fi

    mkdir -p /root/.kube

    ca_path="/root/.kube/ca.pem"
    echo "$cluster_ca" | base64 -d > $ca_path
    kubectl config set-cluster default --server=$cluster_url --certificate-authority=$ca_path

    if [ ! -z "$admin_token" ]; then
      kubectl config set-credentials $admin_user --token=$admin_token
    else
      key_path="/root/.kube/key.pem"
      cert_path="/root/.kube/cert.pem"
      echo "$admin_key" | base64 -d > $key_path
      echo "$admin_cert" | base64 -d > $cert_path
      kubectl config set-credentials $admin_user --client-certificate=$cert_path --client-key=$key_path
    fi

    kubectl config set-context default --cluster=default --user=$admin_user
  else
    kubectl config set-cluster default --server=$cluster_url
    kubectl config set-context default --cluster=default
  fi

  kubectl config use-context default
  kubectl cluster-info
  kubectl version

  echo "Resource setup successful."
}