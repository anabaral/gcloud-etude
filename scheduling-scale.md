# 스케줄 Scaling 시험

토요일 특정 시각 이벤트에 따른 요청 급증이 예상되는 상황에 대한 대응이 가능한지 시험해 보았습니다.

* 특정 시각에 wordpress 배포를 스케일 아웃하는 cronjob을 구성합니다.
  - 이 때 Blue/Green 배포를 고려하여 "Service wordpress 가 가리키는 deployment"를 특정하도록 스크립트를 만들었습니다.
* 이 동작이 적절한 권한을 가지고 실행되도록 Service Account, Role 및 RoleBinding 을 구성합니다.

아래의 cronjob은 하나 뿐이어서 09:40 KST 에 scale out 하는 설정만 존재하는데,<br>
hpa 설정이 이미 존재하므로 요청 감소에 따라 자연스럽게 pod 를 줄이게 되긴 합니다만, <br>
필요하면 10:15 KST 쯤 다시 scale in 하는 설정을 새로운 cronjob 추가할 수 있습니다.

```
$ cat wordpress-scale.yaml 
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: ttc-app
  name: wordpress-scale-role
rules:
- apiGroups:
  - ""
  - "extensions"
  - "apps"
  resources:
  - services
  - "deployments/scale"
  - deployments
  verbs:
  - 'patch'
  - 'get'

---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: wordpress-scale-rolebinding
  namespace: ttc-app
subjects:
- kind: ServiceAccount
  name: wordpress-scaler
  namespace: ttc-app
roleRef:
  kind: Role
  name: wordpress-scale-role
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wordpress-scaler
  namespace: ttc-app

---
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: scaler
spec:
  schedule: "40 00 * * SAT" # in UTC
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: wordpress-scaler
          containers:
          - name: scaler
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - kubectl scale deploy -n ttc-app $(kubectl get service -n ttc-app wordpress -o jsonpath='{.spec.selector.app\.kubernetes\.io/instance}')  --replicas=10
          restartPolicy: OnFailure
```
