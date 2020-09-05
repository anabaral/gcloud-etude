# 스케줄 Scaling 시험

토요일 특정 시각 이벤트에 따른 요청 급증이 예상되는 상황에 대한 대응이 가능한지 시험해 보자.

특정 시각에 wordpress -- 정확히는 Service wordpress 가 가리키는 deployment -- 를 scaling out 하는 cronjob 을 구성하고
이에 적절한 권한을 부여하여 배포하는 구성 파일.

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
  schedule: "10 10 * * SAT" # in UTC
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
