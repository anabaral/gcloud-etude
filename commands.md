# 유용한 명령어들 적어두기

대부분은 독서통신 책에서 나오는 명령어 위주로 정리하지만 경험상 얻은 것을 적기도 하겠음.

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

## Cloud Sql 다루기

Cloud Sql 인스턴스 만들어 둔 것 확인
```
$ gcloud sql instances list
```

패스워드 설정 (mysql 문법 같음. 다른 DB면 문법이 약간 달라질 것 같음)
```
$ gcloud sql users set-password root "%" --password "___<your_password>___" --instance ttc-team14
```

Cloud Sql 은 다양한 접속 방법을 제공한다.
- private ip 로 직접 연결
- (public ip 를 켜고) '연결 이름' 이라는 것을 통해 연결
- SSL 연결

위 두 방법은 [readme.md](https://github.com/anabaral/gcloud-etude) 에서 설명한 바 있는데, <br>
여기서는 나머지 SSL 연결을 다루려 한다.

서버 설정 방법은 단순하다. 
- 일단 공개IP 사용한다는 가정.
- 인증서는 아마 이미 생성되어 있을 것. (없으면 새로 만들면 그뿐) 다운로드 받을 수 있음. 
- 웹 콘솔의 SQL 메뉴에서 서버 인증서를 만든 후 클라이언트 인증서를 만들고 비밀키와 인증서를 다운로드 받을 수 있음.

문제는 Wordpress 이다. 어떻게 변화를 최소화 하면서 (즉 php파일을 덜 건드리면서) 설정을 할 수 있을까? <br>
이걸 처음 생각했을 시점엔 아예 SSL 적용을 배제했었는데, 다시 고민하는 시점엔 이것저것 바꿔가면서 하기 힘들어졌다. (경연 과제 제출했음) <br>
특히 인터넷에 많이 보이는 wp-config.php 파일을 건드리는 방법은 그 파일이 다른 것에 의해서도 잘 바뀌는 성격의 것이라...

- 일단 서버인증서는 이 환경변수 설정과 secret 마운트 조합으로 어떻게 할 수 있을 것 같다: WORDPRESS_DATABASE_SSL_CA_FILE=
- 클라이언트 인증서는? mysql client는 서버 인증서만 파라미터로 주어질 경우에는 클라이언트 인증서를 적당히 생성해서 쓰는 것 같기도 하다. 
  하지만 google cloud 쪽 문서를 보면 생성한 클라이언트 인증서만 받아들이는 것 같다..
  이게 안되면 소용 없는데..



