FROM ubuntu:18.04

MAINTAINER Srinivasa Vasu <srinivasan.surprise@gmail.com>

ARG KUBERNETES_VERSION=

RUN set -x && \
    apt-get update && \
    apt-get install -y python3 python3-yaml jq curl bash && \
    [ -z "$KUBERNETES_VERSION" ] && KUBERNETES_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) ||: && \
    curl -s -LO https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    kubectl version --client && \
    rm -rf /var/lib/apt/lists/*

COPY scripts/j2y /usr/local/bin/
RUN chmod +x /usr/local/bin/j2y

RUN mkdir -p /opt/resource
COPY assets/ /opt/resource/
