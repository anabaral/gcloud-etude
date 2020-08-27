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

이걸 위해 다음을 참고하였음:
- https://cloud.google.com/sql/docs/mysql/connect-kubernetes-engine#secrets
- https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#enable_on_existing_cluster


