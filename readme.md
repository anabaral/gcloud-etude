# Google cloud 연습

회사에서 gcloud를 대상으로 한 어플리케이션 마이그레이션 및 튜닝을 주제로 경연을 열었고 덕분에 순위와 상관없이(?) GKE를 연습해 보고 있음.
이 저장소에는 그 과정에서 얻어지는 산물들을 기록 차원에서 남겨둠.

## 서비스 계정 관리

google cloud 도 서비스 계정이 있고 GKE (kubernetes) 도 역시 서비스 계정이 있음.

다음과 같은 요건이 있었음.
* wordpress 어플리케이션이 연결하는 DB를 google cloud가 제공하는 서비스형 mysql 로 해야 함

이걸 위해서는 다음을 충족시켜 줘야 함.
* google cloud용 서비스 계정 하나 준비 (만들었음. 있는 걸 써도 될지는 모르겠음. 조금 시도 했다가 포기)
* 준비해 둔 gcloud 서비스 계정에게 cloudsql 에 접근하는 권한 부여
* wordpress 어플이 사용하는 k8s 서비스 계정을 알아둠, 혹은 만들어 둠
* k8s 서비스 계정에게 gcloud 서비스 계정 권한(identity) 부여 (명령어 구문을 보면 반대 같은데.. 실제 부여된 걸 보면 이러함)
* 그냥 여기까지 하면 끝 같은데.. 위의 것은 권한부여이고 인증은 따로 필요하기 때문에 gcloud 서비스 계정의 키를 생성
* 이걸 k8s에서 사용할 수 있도록 k8s secret으로 등록

이걸 실행하는 쉘을 만듬. 여러분이 활용하려면 조금 고쳐써야 할 거임
https://github.com/anabaral/gcloud-etude/blob/master/account.sh

사용은 단순
```
$ sh account.sh create  # 생성할 때

$ sh account.sh delete  # 삭제할 
```

이걸 위해 다음을 참고하였음:
- https://cloud.google.com/sql/docs/mysql/connect-kubernetes-engine#secrets
- https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#enable_on_existing_cluster

## container image 보전

불필요할 수도 있어 보이지만 이미지를 항상 latest로 받는 것이 리스크가 있음.
현재 설치되는 버전들의 이미지를 보전할 필요가 있음.

```
$ docker pull docker.io/bitnami/elasticsearch:7.9.0-debian-10-r0
$ docker tag docker.io/bitnami/elasticsearch:7.9.0-debian-10-r0 asia.gcr.io/ttc-team-14/elasticsearch:7.9.0-debian-10-r0
$ docker push asia.gcr.io/ttc-team-14/elasticsearch:7.9.0-debian-10-r0

$ docker pull docker.io/bitnami/minideb:buster
$ docker tag docker.io/bitnami/minideb:buster asia.gcr.io/ttc-team-14/minideb-buster:20200813
$ docker push asia.gcr.io/ttc-team-14/minideb-buster:20200813

$ docker pull docker.io/bitnami/elasticsearch-curator:5.8.1-debian-10-r194
$ docker tag docker.io/bitnami/elasticsearch-curator:5.8.1-debian-10-r194 asia.gcr.io/ttc-team-14/elasticsearch-curator:5.8.1-debian-10-r194
$ docker push asia.gcr.io/ttc-team-14/elasticsearch-curator:5.8.1-debian-10-r194

$ docker pull docker.io/bitnami/elasticsearch-exporter:1.0.2
$ docker tag docker.io/bitnami/elasticsearch-exporter:1.0.2 asia.gcr.io/ttc-team-14/elasticsearch-exporter:1.0.2
$ docker push asia.gcr.io/ttc-team-14/elasticsearch-exporter:1.0.2

$ docker pull nginx:latest
$ docker tag nginx:latest asia.gcr.io/ttc-team-14/nginx:20200813
$ docker push asia.gcr.io/ttc-team-14/nginx:20200813

$ docker pull docker.io/bitnami/wordpress:5.5.0-debian-10-r4
$ docker tag docker.io/bitnami/wordpress:5.5.0-debian-10-r4 asia.gcr.io/ttc-team-14/wordpress:5.5.0-debian-10-r4
$ docker push asia.gcr.io/ttc-team-14/wordpress:5.5.0-debian-10-r4

$ docker pull docker.io/bitnami/apache-exporter:0.8.0-debian-10-r123
$ docker tag docker.io/bitnami/apache-exporter:0.8.0-debian-10-r123 asia.gcr.io/ttc-team-14/apache-exporter:0.8.0-debian-10-r123
$ docker push asia.gcr.io/ttc-team-14/apache-exporter:0.8.0-debian-10-r123

$ docker pull gcr.io/cloudsql-docker/gce-proxy:1.11
$ docker tag gcr.io/cloudsql-docker/gce-proxy:1.11 asia.gcr.io/ttc-team-14/gce-proxy:1.11
$ docker push asia.gcr.io/ttc-team-14/gce-proxy:1.11

```


## wordpress 설치

helm 으로 설치하는데 먼저 다음 파일을 작성함.

이 때 cloudsql 을 어떻게 붙느냐에 따라 내용이 조금 달라짐.
* (1안) cloudsql 과 gke 가 같은 VPC 상에 존재할 경우 private ip 로 직접 붙을 수 있음. 심지어 이 경우 위의 account.sh 도 불필요할 수 있음
* (2안) 보통 권장되는 방법은 위의 account.sh 과 더불어 cloudsql proxy 를 사용하는 방법.

```
$ vi wordpress-values.yaml
wordpressUsername: "ttc"
wordpressPassword: "_my_password_for_ttc_2020_team_"
wordpressBlogName: "TTC+SHOP"
wordpressFirstName: ""
wordpressLastName: "ttc"
wordpressEmail: "ttc@sk-ttc.com"
persistence:
  storageClass: standard
  size: 20Gi
mariadb:
  enabled: false
externalDatabase:
  host: 127.0.0.1    #  2안 기준으로 127.0.0.1 이고 1안 기준은 해당DB의 private ip 를 입력
  user: ttc
  password: _my_another_password_for_ttc_2020_DB_
  database: wordpress
  port: 3306
metrics:
  enabled: true           # prometheus 설치하므로 거기서 수집할 수 있게
replicaCount: 2
sidecars:                 # 2안 기준으로 이 설정이 필요. 1안을 사용할 경우 sidecar 이하 설정은 없어도 됨.
- name: cloudsql-proxy    # k8s에서 google cloud sql 접속하는 가장 권장되는 방법이 sidecar 
  image: asia.gcr.io/ttc-team-14/gce-proxy:1.11
  imagePullPolicy: Always
  ports:
  - name: portname
    containerPort: 3306
  command: ["/cloud_sql_proxy",
            "-instances=ttc-team-14:asia-northeast3:ttc-team14=tcp:3306",
            # If running on a VPC, the Cloud SQL proxy can connect via Private IP. See:
            # https://cloud.google.com/sql/docs/mysql/private-ip for more info.
            # "-ip_address_types=PRIVATE",
            "-credential_file=/secrets/cloudsql/key.json"]
  securityContext:
    runAsUser: 2  # non-root user
    allowPrivilegeEscalation: false
  volumeMounts:
    - name: cloudsql-instance-credentials
      mountPath: /secrets/cloudsql
      readOnly: true
extraVolumes:
- name: cloudsql-instance-credentials
  secret:
    secretName: cloudsql-instance-credentials  #  이게 위의 account.sh 로 생성한 시크릿임. 
```

설치 명령은 단순
```
$ kubectl create ns ttc-app                                      # 네임스페이스 안 만들었다면 만들어 주기
$ helm repo add bitnami https://charts.bitnami.com/bitnami       # helm repo 추가 안했다면 추가하기
$ helm install -n ttc-app wordpress --version 9.5.1 -f wordpress-values.yaml bitnami/wordpress
```
버전은 미리 ```helm fetch bitnami/wordpress``` 로 받아보고 알아보았음

설치제거 명령도 단순
```
$ helm delete -n ttc-app wordpress
```

## wordpress 에 plugin 설치

plugin 설치는 두 가지 방법이 존재함
* 화면에서 검색 및 설치
* wordpress 설치된 VM/Container 안에서 wp plugin install 명령 사용

당장 필요한 것이 무언지 찾아서 설치하기에는 첫번째 방법이 좋은데, 자동화를 고려하면 두번째를 준비해야 함.
일단 첫번째 방법 과정에서 플러그인 이름들을 식별해 두고, 이를 다음 쉘 작성에 참고함

https://github.com/anabaral/gcloud-etude/blob/master/plugin.sh

사용은 단순:
```
$ sh plugin.sh install     # (설치하기로 적어둔 것들) 모두 설치 및 활성화
```
로그를 눈여겨 봐야 함. 서버 상태나 기타 알 수 없는 이유로 설치가 실패하는 경우가 있음. <br>
다행히도 보통 한 번 더 실행하면 (이미 설치한 것은 통과하면서) 잘 설치됨. <br>
(오픈소스의 길은 험난하다)
```
$ sh plugin.sh uninstall   # 모두 역순으로 비활성화 후 제거
```

## elasticsearch 설치

역시 helm 으로 설치했는데, wordpress 내부에서 사용하는 용도라서 외부 접속 등의 설정이 불필요해서 간단하게 작성..
하고 싶었는데.. 이미지 끌어오는 것만 이게 뭐냐..

```
$ vi elasticsearch-values.yaml
global:
  storageClass: standard
image:
  registry: asia.gcr.io
  repository: ttc-team-14/elasticsearch
  tag: 7.9.0-debian-10-r0
curator:
  enabled: true
  image:
    registry: asia.gcr.io
    repository: ttc-team-14/elasticsearch-curator
    tag: 5.8.1-debian-10-r194
metrics:
  image:
    registry: asia.gcr.io
    repository: ttc-team-14/elasticsearch-exporter
    tag: 1.0.2
sysctlImage:
  registry: asia.gcr.io
  repository: ttc-team-14/minideb-buster
  tag: "20200813"
volumePermissions:
  image:
    registry: asia.gcr.io
    repository: ttc-team-14/minideb-buster
    tag: "20200813"
master:
  persistence:
    size: 1Gi
    accessModes: ReadWriteMany
data:
  persistence:
    size: 2Gi
    accessModes: ReadWriteMany
metrics:
  enabled: true
```

설치는 단순
```
$ helm install -n ttc-app elasticsearch --version 12.6.2 -f elasticsearch-values.yaml bitnami/elasticsearch
```
버전은 미리 ```helm fetch bitnami/elasticsearch``` 로 받아보고 알아보았음

이후 wordpress 관리자 화면에서 elasticsearch 연결 서비스 ( http://elasticsearch-elasticsearch-coordinating-only.ttc-app:9200 ) 등록하면 완료

