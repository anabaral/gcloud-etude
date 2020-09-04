# 블루그린 배포 간략 구현하기

분석하여 다음과 같은 현황을 얻음:
- WAS 는 Wordpress 기반으로 만들어져 있으므로 
  이 어플리케이션의 유지보수는 다음 정도로 생각할 수 있음.

|유지보수 범위|서비스 중단 가능성|
|------------|------------------|
|wordpress 자체의 업그레이드 | 이미지 버전 변경 --> 디플로이 바뀜 |
|현존 플러그인의 업그레이드  | 플러그인 비활성화 시간 필요 |
|새 플러그인의 개발/추가     | 버그테스트 후 재 변경 가능성 |


- 이 모두가 아주 짧게라도 서비스의 중단을 필요로 할 수 있으므로, 서비스의 무중단 배포를 가능하려면
  블루그린 배포가 필요할 것으로 생각됨.

실제 환경에서 블루그린 배포는 더 준비하고 구성할 게 많을 텐데, 여기서는 기본에만 집중해서 다음만으로 구성하겠음.
- 배포(Deployment)는 여러 배포가 존재할 수 있음
  * 기본적으로 일자 나 버전을 부여하여 배포해 이름으로 구분
- 본 서비스(Service)는 이 배포들 중 하나를 가리키며 이것이 블루(blue)배포본임
- 그린(green) 배포본이 디플로이가 되면 이를 테스트하기 위한 다른 서비스(Service) 를 통해 테스트
- 테스트가 완료되면 본 서비스 디스크립터를 git 저장소에서 편집해 commit/push 함
- 변경은 Argocd 에 의해 인지되어 서비스가 새 배포를 가리키게 되며 이 배포가 이제 블루(blue)배포본이 됨
- 변경이력은 git 저장소에서 관리됨

## 도안

![blue-green deploy](https://github.com/anabaral/gcloud-etude/blob/master/bluegreen.gif?raw=true)

## 추가 내용

- 본 Service는 운영 ingress (예: www.team14.sk-ttc.com ) 가 연결되고 Test Service는 테스트용 ingress (예: green.team14.sk-ttc.com ) 가 연결됨. 
- 그림에는 Test Service 가 본 배포 이후 그냥 떨어지는 것으로만 표현 했는데, 다음 배포를 대비하여 미리 그린 배포 쪽에 연결해 둘 수 있음.


## green 테스트용 ingress 와 proxy, service 준비

wordpress green-service
```
$ vi wordpress-test-svc.yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: wordpress-green
    meta.helm.sh/release-namespace: ttc-app
  labels:
    app: wordpress
    app.kubernetes.io/instance: wordpress-green
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: wordpress
  name: wordpress-green
  namespace: ttc-app
spec:
  ports:
  - name: http
    port: 80
    nodePort: 32001
    protocol: TCP
    targetPort: http
  - name: https
    port: 443
    nodePort: 32002
    protocol: TCP
    targetPort: https
  - name: metrics
    port: 9117
    protocol: TCP
    targetPort: metrics
  selector:
    app.kubernetes.io/instance: wordpress-20200903
    app.kubernetes.io/name: wordpress
  sessionAffinity: None
  type: NodePort

$ kubectl apply -f wordpress-test-svc.yaml
```
nodeport 충돌 막는 것과 이름 구분하는 것이 신경쓸 전부임.

proxy configmap / deployment / service
```
$ vi frontend-test.yaml
apiVersion: v1
data:
  default.conf: |-
    server {
      listen 80;
      # server_name _; # change this

      # global gzip on
      gzip on;
      gzip_min_length 10240;
      gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml;
      gzip_disable "MSIE [1-6]\.";

      add_header Cache-Control public;

      ## HTTP Redirect ##
      if ($http_x_forwarded_proto = "http") {
          return 301 https://$host$request_uri;
      }

      location / {
        proxy_pass http://wordpress-green.ttc-app:80;
        proxy_buffering on;
        proxy_buffers 12 12k;
        proxy_redirect default;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header Host green.team14.sk-ttc.com;
      }
    }
kind: ConfigMap
metadata:
  name: frontend-green-config
  namespace: ttc-app
  labels:
    app: proxy-green
    release: frontend
---
apiVersion: v1
kind: Service
metadata:
  name: proxy-green
  namespace: ttc-app
  labels:
    app: proxy
    release: frontend
spec:
  selector:
    app: proxy-green
    tier: web
  ports:
  - port: 80
    nodePort: 32003
    targetPort: 80
  type: NodePort
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: proxy-green
  namespace: ttc-app
  labels:
    app: proxy-green
    release: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: proxy-green
      tier: web
  template:
    metadata:
      labels:
        app: proxy-green
        tier: web
    spec:
      containers:
      - name: nginx
        image: asia.gcr.io/ttc-team-14/nginx:20200813
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /etc/nginx/conf.d/default.conf
          name: nginx-conf
          readOnly: true
          subPath: default.conf
        resources:
          requests:
            cpu: 50m
            memory: 100Mi
          limits:
            cpu: 50m
            memory: 100Mi
      volumes:
      - name: nginx-conf
        configMap:
          defaultMode: 420
          name: frontend-green-config

$ kubectl apply -f frontend-test.yaml
```
양이 많지만 요점은 
- 이름을 green 배포에 어울리는 것으로 바꾸고 
- nginx 설정에서 전달될 서버명 조정
- nodePort가 충돌하지 않도록 조정하는 것 정도임
- 이미지는 동일해도 상관없음

ingress

```
$ kubectl edit ingress ttc-app   # 혹은 파일을 이용해 편집
...
spec:
  rules:
  ...
  - host: green.team14.sk-ttc.com
    http:
      paths:
      - backend:
          serviceName: proxy-green
          servicePort: 80
        path: /*
```

DNS

위의 green.team14.sk-ttc.com 을 같은 IP로 등록해 줘야 함.


## 구현

개요는 다음과 같음:
- 현재 구동 중인 시스템은 wordpress
- 새로 구동 중인 시스템은 wordpress-20200903 으로 하려 함.

공교롭게도 최신 helm chart 버전과 이미지 버전들이 아주 작게나마 바뀌어 있어 이를 기반으로 업그레이드를 진행한다고 가정함.

### 이미지 준비

그냥 오픈 이미지를 변경 없이 쓸 거면 불필요하겠지만.. 변경이 있는 케이스로 가정하고 프라이빗 저장소에 이미지를 부어 놓음 
```
# 최신 helm 버전 확인 : 9.5.3
# 최신 helm 의 이미지 변경 확인하여 이를 gcr에 넣어주자
$ docker pull docker.io/bitnami/wordpress:5.5.1-debian-10-r0
...
$ docker tag docker.io/bitnami/wordpress:5.5.1-debian-10-r0 asia.gcr.io/ttc-team-14/wordpress:5.5.1-debian-10-r0
$ docker push asia.gcr.io/ttc-team-14/wordpress:5.5.1-debian-10-r0

$ docker pull docker.io/bitnami/apache-exporter:0.8.0-debian-10-r135
...
$ docker tag docker.io/bitnami/apache-exporter:0.8.0-debian-10-r135 asia.gcr.io/ttc-team-14/apache-exporter:0.8.0-debian-10-r135
$ docker push asia.gcr.io/ttc-team-14/apache-exporter:0.8.0-debian-10-r135
```

### 파라미터 준비

```
$ mkdir blue_green_test
$ vi wordpress-values.yaml
wordpressUsername: "ttc"
wordpressPassword: "<password_for_ttc>"
wordpressBlogName: "TTC_SHOP_NEW"
wordpressFirstName: ""
wordpressLastName: "ttc"
wordpressEmail: "ttc@sk-ttc.com"
persistence:
  existingClaim: wordpress-pvc  # 마이너 업그레이드이니 볼륨은 기존 것을 사용한다는 의미로
mariadb:
  enabled: false
externalDatabase:
  #host: 127.0.0.1
  host: 10.58.160.3
  user: ttc
  password: <DB_PASSWORD>
  database: wordpress
  port: 3306
image:
  registry: asia.gcr.io
  repository: ttc-team-14/wordpress
  tag: 5.5.1-debian-10-r0
metrics:
  enabled: true
  image:
    registry: asia.gcr.io
    repository: ttc-team-14/apache-exporter
    tag: 0.8.0-debian-10-r135
replicaCount: 1   # 테스트 후 올림
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - wordpress
        topologyKey: kubernetes.io/hostname
      weight: 70
service:
  type: ClusterIP
```

위에서 마이너 업그레이드라 할지라도 플러그인 업그레이드 같이 공유 볼륨이 변경되면서 기존 시스템에 영향이 있을 때는 같은 저장소를 쓰면 
블루그린 배포의 의미가 없음. 그럴 경우엔 새 저장소를 띄우고 복제하는 절차를 밟아야 함.

### 새 배포 설치

다음과 같이 기존 배포와 이름을 달리 하여 설치.

```
$ helm install -n ttc-app wordpress-20200903 --version 9.5.3 -f wordpress-values.yaml bitnami/wordpress
```

여담이지만 네임스페이스가 동일해야 Service 디스크립터를 바꿔 순간 교체를 할 수 있음.

이 때 만들어지는 Service는 과감히 삭제하자. (파라미터로 안 만들어지게 할 수 있으면 좋겠는데)
```
$ kubectl delete svc wordpress-20200903
```
대신 그린 Service 를 미리 만들어 두었으니 이를 편집해 wordpress-20200903 을 바라보게 한다.
```
$ kubectl edit svc wordpress-green   # 이건 git + argocd 로 작업할 수도 있음
...
  selector:
    app.kubernetes.io/instance: wordpress-20200903
    app.kubernetes.io/name: wordpress
```

### 새 배포 사용

테스트가 충분히 되어 이걸 서비스해도 되겠다 싶으면 교체를 진행한다.

뒤에 ArgoCD 를 이용한 반 자동 sync 설정을 할 것인데 여기는 테스트때 사용한 명령어 기준으로 설명함.<br>
그냥 수작업 bluegreen 으로 간다면 이것만으로도 기능적으로 충분하긴 함.

복제 수를 조정해 기존 서비스에 맞춘다
```
$ vi wordpress-hpa.yaml  # 기존 블루 서비스의 규칙을 참조해 작성
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  annotations:
  name: wordpress-20200903  # 기존것과 구분
  namespace: ttc-app
spec:
  maxReplicas: 30
  minReplicas: 3
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: wordpress-20200903   # 기존것과 구분 
  targetCPUUtilizationPercentage: 30

$ kubectl apply -f wordpress-hpa.yaml
```

서비스를 교체
```
$ kubectl edit service -n ttc-app wordpress
...
  selector:
    app.kubernetes.io/instance: wordpress-20200903  # 이것만 고침
    app.kubernetes.io/name: wordpress
...
```

다른 한편으론 green 서비스를 삭제하거나 기존의 블루 서비스로 연결한다.


## ArgoCD를 이용한 semi-automation 설정

### Git 설정

Gitea 를 설치해 둔 것을 이용한다. (설치 과정은 https://github.com/SEOTAEEYOUL/GKE/tree/master/gitea )

저장소는 화면에서 미리 만들어 두고 다음으로 연동, README.md 만 등록
```
$ touch README.md
$ git init
$ git config --global user.email "anabaral@gmail.com"
$ git config --global user.name "selee"
$ git add README.md
$ git commit -m "first commit"
$ git remote add origin http://gitea.team14.sk-ttc.com:80/selee/wordpress-deploy.git
$ git push -u origin master
```

서비스 파일들 등록
```
# 이미 파일로 만들어 둔 게 있으면 그걸 쓰면 되고, 아니면 아래처럼 파일 생성
$ kubectl get svc -n ttc-app wordpress -o yaml > wordpress-svc.yaml
# 위의 파일에서 쓸모없는(?) 정보를 없애는 등의 다듬기는 필요함. 이를테면
# metadata.annotations.kubectl.kubernetes.io/last-applied-configuration 이라거나
# metadata.resourceVersion , metadata.uid 따위

$ git add wordpress-svc.yaml
$ git commit -m "current config"
$ git push -u origin master
Username for 'http://gitea.team14.sk-ttc.com:80': selee
Password for 'http://selee@gitea.team14.sk-ttc.com:80':
```

여기서는 wordpress-green-svc 도 같은 방식으로 만들어 올려 두었음

### ArgoCD 설정

ArgoCD 도 설치해 둔 것을 이용함. (설치는 https://github.com/SEOTAEEYOUL/GKE/tree/master/argocd )

Settings 메뉴로 가면 다음을 차례로 설정해야 한다:
- Repositories
  * Name: wordpress-deploy
  * Repository: http://gitea.team14.sk-ttc.com/selee/wordpress-deploy
- Clusters 
  * 여긴 편집할 필요 없음. argocd 가 k8s cluster에 떠 있으므로 in-cluster 라는 항목이 있음을 확인
- Projects
  * Add Project 하고 다음 정도만 입력
    - Name: ttc-app
    - Source Repositories: *
    - Destinations: SERVER=https://kubernetes.default.svc , NAMESPACE=ttc-app
    - Whitelisted 어쩌구들은 다 * * 로 채움

Manage your applications 메뉴에서 [NEW APP] 버튼 누르고 다음을 설정:
- Application Name: wordpress
- Project: ttc-app
- Sync Policy: Manual (커밋하고 바로 반영되기보다는 최종 확인하기 위해)
- Repository URL: http://gitea.team14.sk-ttc.com/selee/wordpress-deploy
- Path: *
- Cluster: in-cluster
- Namespace: ttc-app
- [CREATE] 버튼으로 마무리

처음엔 Out of Sync 라고 나올 수 있는데, Sync 수행해 주면 됨.

![ArgoCd 화면](https://github.com/anabaral/gcloud-etude/blob/master/wordpress-bluegreen-argocd.png?raw=true)


