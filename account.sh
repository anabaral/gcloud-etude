#!/bin/sh
#
PROJECT_ID=ttc-team-14
NS=ttc-app
KSA_NAME=default
SA_NAME=cloudsql-proxy
WORKING_DIR=$HOME/ttc_etude/wordpress
DB_USER=root
DB_PASS=database_password_2020_ttc_team14!!
ROLE=roles/cloudsql.editor
create(){
  gcloud iam service-accounts create $SA_NAME --display-name $SA_NAME
  sleep 2 # 여러 번 실행하다 보면  아래 명령이 실행되는 시점에 위의 서비스 계정이 없을 때가 있더라
  SA_EMAIL=$(gcloud iam service-accounts list --filter=displayName:$SA_NAME --format='value(email)')  echo "sa_id= $SA_EMAIL"  # cloudsql-proxy@ttc-team-14.iam.gserviceaccount.com
  # kubectl create sa -n ${NS} ${KSA_NAME}
  gcloud projects add-iam-policy-binding $PROJECT_ID --role ${ROLE} --member serviceAccount:$SA_EMAIL
  gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NS}/${KSA_NAME}]" $SA_EMAIL
  echo "이미 있는 k8s-serviceaccount 작업이면 다음은 에러날 겁니다"
  kubectl annotate serviceaccount --namespace ${NS} ${KSA_NAME} iam.gke.io/gcp-service-account=$SA_EMAIL
  gcloud iam service-accounts keys create $WORKING_DIR/key.json --iam-account $SA_EMAIL
  # kubectl create secret generic cloudsql-db-credentials --from-literal username=$DB_USER --from-literal password=$DB_PASS
  kubectl create secret generic cloudsql-instance-credentials --from-file $WORKING_DIR/key.json
}
delete(){
  SA_EMAIL=$(gcloud iam service-accounts list --filter=displayName:$SA_NAME --format='value(email)')
  kubectl delete secret cloudsql-instance-credentials
  kubectl delete secret cloudsql-db-credentials
  gcloud projects remove-iam-policy-binding ${PROJECT_ID} --member serviceAccount:$SA_EMAIL --role ${ROLE}
  # kubectl delete sa -n ${NS} ${KSA_NAME}
  rm -f $WORKING_DIR/key.json
  gcloud iam service-accounts delete $SA_EMAIL --quiet
}
if [ "$1" = "create" ]; then
  create
elif [ "$1" = "delete" ]; then
  delete
fi
