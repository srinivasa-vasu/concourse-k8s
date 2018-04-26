# concourse-k8s

Deploy to [Kubernetes](https://github.com/kubernetes/kubernetes) from [Concourse](https://concourse.ci/).

## Resource Type

Define the resource type in the pipeline:
```
resource_types:
- name: k8s
  type: docker-image
  source:
    repository: srinivasavasu/concourse-k8s
```
## Source Configuration

Add the source configuration to the pipeline:
```
- name: kubernetes-deployment
  type: k8s
  source:
    cluster_url: {{K8S_CLUSTER_URL}}
    namespace: {{K8S_NAMESPACE}}
    cluster_ca: {{K8S_CA_BASE64}}
    admin_user: {{K8S_ADMIN_USER}}
    admin_token: {{K8S_ADMIN_TOKEN}}
```
Replace the var between `{{ }}` with actual values or define it in the pipeline so that it can be referred like above


* `cluster_url`: *Required.* URL to Kubernetes Master API service
* `cluster_ca`: *Optional.* Base64 encoded PEM. Required if `cluster_url` is https.
* `admin_user`: *Optional.* Admin user for Kubernetes.  `admin_user`/`admin_token` or `admin_key`/`admin_cert` are required if `cluster_url` is https.
* `admin_token`: *Optional.* Admin user token for Kubernetes.  `admin_user`/`admin_token` or `admin_key`/`admin_cert` are required if `cluster_url` is https.
* `admin_key`: *Optional.* Base64 encoded PEM. Required if `cluster_url` is https and no `admin_user`/`admin/token` is provided.
* `admin_cert`: *Optional.* Base64 encoded PEM. Required if `cluster_url` is https and no `admin_user`/`admin/token` is provided.
* `namespace`: *Optional.* Kubernetes namespace the objects will be deployed into. (Default: default)

## Behavior

### `check`: Checks for newer versions

### `in`: Not implemented yet

### `out`: Deploys various k8s objects

## Deploy Configuration (PUT)

#### Parameters

```
  - put: kubernetes-deployment
    params:
      resource_type: deployment
      resource_name: app-name
      image_name: {{REPO_URL}}
      image_tag: {{APP_TAG_VERSION}}
      env_values:
      - name: name1
        value: value1
      - name: name2
        value: value2
      command:
      - /bin/sh
      - c
      - "echo 'hello thr'"
      port_values:
      - name: web
        containerPort: "8080"
      readiness_probe:
        httpGet:
          path: /management/health
          port: web
```

* `resource_type`: *Required.* K8s resource type (like deployment, service, configmap etc) 
* `resource_name`: *Required.* Name of the k8s resource

Based on the `resource_type` few other params may be required. Following k8s objects can be configured now,
* Deployment
* Service
* ConfigMap
* Secret
* Ingress
* Job
* StatefulSet
* MultiContainerDeployment (deploying 1/n initContainers and 1/n containers in a deployment manifest)

Support will be added to configure more objects in the future.

## Example

### Out

Define the resource:

```
resources:
- name: kubernetes-deployment
  type: k8s
  source:
    cluster_url: {{K8S_CLUSTER_URL}}
    namespace: {{K8S_NAMESPACE}}
    cluster_ca: {{K8S_CA_BASE64}}
    admin_user: {{K8S_ADMIN_USER}}
    admin_token: {{K8S_ADMIN_TOKEN}}
```

Add to job:
#### deployment | dp

```
jobs:
  # ...
  plan:
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
```

#### service | sv
```
jobs:
  # ...
  plan:
  - put: kubernetes-deployment
    params:
      resource_type: service '*'
      resource_name: app_name '*'
      stateful: true '*'(Mandatory for creating headless service, if not optional)
      port_values: '*'
      - name: web
        port: "8080"
        targetPort: "8080"
```

#### configmap | cm
```
jobs:
  # ...
  plan:
  - put: kubernetes-deployment
    params:
      resource_type: configmap '*'
      resource_name: app_name '*'
      config_data: '*'
        app.properties: |
          key1=value1
          key2=value2
```

#### secret | se
```
jobs:
  # ...
  plan:
  - put: kubernetes-deployment
    params:
      resource_type: secret '*'
      resource_name: app_name '*'
      config_data: '*'
        app.properties: |
          key1=value1
          key2=value2
```

#### job | jb
```
jobs:
  # ...
  plan:
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
```

#### ingress | ig
```
jobs:
  # ...
  plan:
  - put: kubernetes-deployment
    params:
      resource_type: ingress '*'
      resource_name: app_name '*'
      service_port: "8080" '*'
      host: app-name.domain.com '*'
```

#### statefulset | st
```
jobs:
  # ...
  plan:
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
```

#### multicontainerdeployment | md
```
jobs:
  # ...
  plan:
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
```
*entries marked with '\*' are mandatory*

**You can also have multiple puts in a plan as well**

```
jobs:
  # ...
  plan:
  - put: kubernetes-deployment
    params:
      resource_type: deployment
      resource_name: spring-music
      image_name: {{REPO_URL}}
      image_tag: {{APP_TAG_VERSION}}
      env_values:
      - name: SPRING_PROFILES_ACTIVE
        value: prod
      - name: SPRING_DATA_MONGODB_DATABASE
        value: app1
      - name: SPRING_DATA_MONGODB_URI
        value: "mongodb://app1-mongodb-0.app1-mongodb.bbase:27017"
      - name: JAVA_OPTS
        value: " -Xmx256m -Xms256m"
      command:
      - /bin/sh
      - c
      - "echo 'hello thr'"
      port_values:
      - name: web
        containerPort: "8080"
      readiness_probe:
        httpGet:
          path: /management/health
          port: web
  - put: kubernetes-deployment
    params:
      resource_type: configmap
      resource_name: spring-music
      config_data:
        game-properties-file-name: game.properties
        game.properties: |
          enemies=aliens
          lives=3
  - put: kubernetes-deployment
    params:
      resource_type: service
      resource_name: spring-music
      port_values:
      - name: web
        port: "8080"
```
