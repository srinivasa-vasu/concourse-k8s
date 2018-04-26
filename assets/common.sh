#!/bin/bash
set -e

log() {

  LEVEL=INFO
  while test $# -gt 0
  do
    case $1 in
      -l) shift; LEVEL=$1 ;;
      *) break;
    esac
    shift
  done

  echo [$LEVEL] $*
}

die() {

  TYPE=
  if [ $# -gt 1 ]; then
    TYPE=$1
    shift
  fi

  log -l ERROR ">>> $@ <<<"

  if [[ -n $TYPE ]]; then
      log "Pls find the sample usage below:"
      log ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
      case $TYPE in
        $DEPLOYMENT|$DP)
        cat <<EOF
          - put: kubernetes-deployment
            params:
              resource_type: deployment '*'
              resource_name: app '*'
              replica: 1
              image_name: app_name '*'
              image_tag: app_tag '*'
              env_values:
              - name: app_env_key
                value: app_env_value
              resources:
                requests:
                  memory: "256Mi"
                  cpu: "500m"
                limits:
                  memory: "512Mi"
                  cpu: "1"
              command:
              - "echo hello there"
              port_values:
              - name: web
                containerPort: "8080"
              readiness_probe:
                httpGet:
                  path: /management/health
                  port: web
                initialDelaySeconds: 20
                periodSeconds: 15
                failureThreshold: 3
              livenessProbe:
                httpGet:
                  path: /management/health
                  port: web
                initialDelaySeconds: 120
              volumes:
                - name: volume_name
                  mountPath: volume_mount_path
EOF
        ;;
        $STATEFULSET|$ST)
        cat <<EOF
          - put: kubernetes-deployment
            params:
              resource_type: statefulset '*'
              resource_name: app '*'
              image_name: app_name '*'
              image_tag: app_tag '*'
              service_name: app_service_name '*'
              volume_name: app_storage_name '*'
              storage_class_name: app_storage_class_name '*'
              storage_volume: 10Gi
              env_values:
              - name: app_env_key
                value: app_env_value
              resources:
                requests:
                  memory: "256Mi"
                  cpu: "500m"
                limits:
                  memory: "512Mi"
                  cpu: "1"
              command:
              - "echo hello there"
              port_values:
              - name: web
                containerPort: "8080"
              readiness_probe:
                httpGet:
                  path: /management/health
                  port: web
                initialDelaySeconds: 20
                periodSeconds: 15
                failureThreshold: 3
              livenessProbe:
                httpGet:
                  path: /management/health
                  port: web
                initialDelaySeconds: 120
              volumes:
                - name: volume_name
                  mountPath: volume_mount_path
                  config: volume_configmap_ref
EOF
        ;;
        $MULTICONTAINERDEPLOYMENT|$MD)
        cat <<EOF
          - put: kubernetes-deployment
            params:
              resource_type: multicontainerdeployment '*'
              resource_name: app '*'
              replica: 1
              init_containers: '*'
                - name: init_app_name
                  image: init_app_image
                  command:
                    - '/bin/sh'
                    - '-c'
                    - |
                        while true
                        do
                          echo "Hi there!"
                          break
                        done
              main_containers: '*'
              - name: app_name
                image: app_image
                imagePullPolicy: IfNotPresent
                env:
                - name: app_env_key
                  value: app_env_value
                resources:
                  requests:
                    memory: "256Mi"
                    cpu: "500m"
                  limits:
                    memory: "512Mi"
                    cpu: "1"
                ports:
                - name: web
                  containerPort: 8080
                readinessProbe:
                  httpGet:
                    path: /management/health
                    port: web
                  initialDelaySeconds: 20
                  periodSeconds: 15
                  failureThreshold: 3
                livenessProbe:
                  httpGet:
                    path: /management/health
                    port: web
                  initialDelaySeconds: 120
EOF
        ;;
        $JOB|$JB)
        cat <<EOF
          - put: kubernetes-deployment
            params:
              resource_type: job '*'
              resource_name: app '*'
              image_name: app_name '*'
              image_tag: app_tag '*'
              env_values:
              - name: app_env_key
                value: app_env_value
              command:
              - "echo hello there"
EOF
        ;;
        $SERVICE|$SV)
        cat <<EOF
          - put: kubernetes-deployment
            params:
              resource_type: service '*'
              resource_name: app_name '*'
              stateful: true '*'(Mandatory for creating headless service, if not optional)
              port_values: '*'
              - name: web
                port: "8080"
                targetPort: "8080"
EOF
        ;;
        $CONFIGMAP|$CM)
        cat <<EOF
          - put: kubernetes-deployment
            params:
              resource_type: configmap '*'
              resource_name: app_name '*'
              config_data: '*'
                app.properties: |
                  key1=value1
                  key2=value2
EOF
        ;;
        $SECRET|$SE)
        cat <<EOF
          - put: kubernetes-deployment
            params:
              resource_type: secret '*'
              resource_name: app_name '*'
              config_data: '*'
                app.properties: |
                  key1=value1
                  key2=value2
EOF
        ;;
        $INGRESS|$IG)
        cat <<EOF
          - put: kubernetes-deployment
            params:
              resource_type: ingress '*'
              resource_name: app_name '*'
              service_port: "8080" '*'
              host: app-name.domain.com '*'
EOF
        ;;
        *)
        ;;
      esac
      log "Mandatory params are indicated with '*'"
      log ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  fi
  exit 1
}

initialize() {
  log "Initializing kubectl..."
  payload=$1
  source=$2
  # Setup kubectl
  cluster_url=$(jq -r '.source.cluster_url // ""' < $payload)
  if [ -z "$cluster_url" ]; then
    die "Invalid payload (missing cluster_url)"
  fi
  if [[ "$cluster_url" =~ https.* ]]; then

    cluster_ca=$(jq -r '.source.cluster_ca // ""' < $payload)
    admin_key=$(jq -r '.source.admin_key // ""' < $payload)
    admin_cert=$(jq -r '.source.admin_cert // ""' < $payload)
    admin_user=$(jq -r '.source.admin_user // "admin"' < $payload)
    admin_token=$(jq -r '.source.admin_token // ""' < $payload)

    if [ -z "$admin_user" ] || [ -z "$admin_token" ]; then
      if [ -z "$admin_key" ] || [ -z "$admin_cert" ]; then
        die "Missing creds info: Either provide (admin_user and admin_token) or (admin_key and admin_cert)"
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

  log "Resource setup successful."
}

#initialize constants
DEPLOYMENT=deployment
DP=dp
JOB=job
JB=jb
MULTICONTAINERDEPLOYMENT=multicontainerdeployment
MD=md
INGRESS=ingress
IG=ig
SECRET=secret
SE=se
CONFIGMAP=configmap
CM=cm
STATEFULSET=statefulset
ST=st
SERVICE=service
SV=sv
