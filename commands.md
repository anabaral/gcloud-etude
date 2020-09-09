# 유용한 명령어들 적어두기

## 실행 권한 획득

VM이나 혹은 Google cloud sdk(=gcloud, 쉽게 생각해서) 를 설치한 클라이언트에서 gcloud 명령 실행 권한을 획득하는 방법
```
$ gcloud auth login
```
이 명령은 인터랙티브하게 진행됨. (로그인한) 브라우저에서 권한 허용하는 작업이 이어진다.

내가 실행하는 gcloud 명령은 위의 것으로 해소되지만 내가 실행하는 어플리케이션에 권한을 주려면:
```
$ gcloud auth application-default login

You are running on a Google Compute Engine virtual machine.
The service credentials associated with this virtual machine
will automatically be used by Application Default
Credentials, so it is not necessary to use this command.

If you decide to proceed anyway, your user credentials may be visible
to others with access to this virtual machine. Are you sure you want
to authenticate with your personal account?

Do you want to continue (Y/n)?  
```
위 문장은 이미 Google VM 에서 권한을 얻은 상태기 때문에 기본권한으로 가능하다.. 는 뜻 같다.
불필요하기 때문에 패스.

하지만 자기 PC에서 하거나, 혹은 자신이 로그인한 계정 말고 다른 계정으로 하게 될 때는 필요한 것 같다.
특히 다른 계정으로 하려면 웹 콘솔에서 메뉴 - API 및 서비스 - 서비스 계정 으로 들어가 키를 생성하고 
이를 자신의 계정 홈의 적당한 곳에 넣어야 하는 것 같다.
(참조: https://jungwoon.github.io/google%20cloud/2018/01/11/Google-Application-Default-Credential/ )


