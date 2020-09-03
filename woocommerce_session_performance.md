# Wordpress Woocommerce 에서 세션 성능 증가 노력

현재 실패상태이지만 지금까지 해온 노력을 적어 봅니다.

Wordpress 의 세션 관리와 별개로 woocommerce 는 별도로 세션을 관리하고 있습니다.

## php에서 통상적으로 쓰이는 세션 관리 코드

php에서 세션 관리할 때 보통 쓰이는 코드는 다음과 같습니다:
```
session_start();
...
$_SESSION["city"] = "부산";
```

이 방식을 쓰면 별도의 세션 핸들러를 지정하지 않은 상황에서는 특정 디렉터리 ```/var/lib/php/sessions``` 의 파일로 저장한다고 합니다.

다만 wordpress 코어 기능에선 이 패턴을 **쓰지 않는다고** 합니다. 

(사실 소스를 뒤져 보면 몇몇 플러그인에서 사용하긴 함)

## wordpress 의 세션 관리 코드

wordpress에서는 위의 패턴을 직접 쓰는 대신 다음과 같은 코드들로 세션을 관리하는 것 같습니다.

```
wordpress/wp-includes/class-wp-session-tokens.php
wordpress/wp-includes/class-wp-user-meta-session-tokens.php  # 위를 상속
```
이 코드를 오버라이드해서 redis 세션으로 대체하는 코드도 존재합니다:
https://github.com/ethitter/WP-Redis-User-Session-Storage (phpredis 가 설치되어야 사용 가능)
```
...
add_filter( 'session_token_manager', 'wp_redis_user_session_storage' ); /* 세션 관리 로직을 제공한 것으로 대체하는 코드 */
```
그러나 이것을 대체해 봐야 woocommerce에서 사용하는 것과는 무관합니다.

## woocommerce 에서 사용하는 세션 관리 코드

woocommerce 에서는 세션에 해당하는 정보들을 DB에 저장합니다. 다음은 세션 저장용 테이블 명세입니다.
```
MySQL [wordpress]> describe wp_woocommerce_sessions
    -> ;
+----------------+---------------------+------+-----+---------+----------------+
| Field          | Type                | Null | Key | Default | Extra          |
+----------------+---------------------+------+-----+---------+----------------+
| session_id     | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
| session_key    | char(32)            | NO   | UNI | NULL    |                |
| session_value  | longtext            | NO   |     | NULL    |                |
| session_expiry | bigint(20) unsigned | NO   |     | NULL    |                |
+----------------+---------------------+------+-----+---------+----------------+
```

이를 핸들하기 위한 클래스 코드가 존재합니다.
```
wordpress/wp-content/plugins/woocommerce/includes/class-wc-session-handler.php
```
코드를 보면 글로벌 변수로 선언된 데이터베이스 객체 wpdb 에 직접 접근해서 SQL을 실행합니다.
여기서 어떻게 성능 향상이 가능하지..?

코드를 완전히 뜯어고쳐 놓은 새로운 플러그인이 나오면 가능한데 검색에서는 아쉽게도 나오지 않습니다.

유일하게 생각할 수 있는 옵션은 메모리 엔진으로 테이블을 재생성 하는 것인데 다음 테스트 코드에서 불가함을 확인했습니다:
```
> create table wp_woocommerce_sessions_test (
    ->     session_id  bigint(20) unsigned not null auto_increment primary key,
    -> session_key char(32) not null unique,
    -> session_value longtext not null,
    -> session_expiry bigint(20) unsigned not null
    -> ) ENGINE=MEMORY;
ERROR 3161 (HY000): Storage engine MEMORY is disabled (Table creation is disallowed).
```
google cloud sql 은 메모리 엔진을 지원하지 않습니다.

결국 하려면 세션관리용 mysql을 별도로 설치해서 메모리 엔진 테이블을 생성해야 하는데
이게 가능하려면 위의 소스 ```class-wc-session-handler.php``` 를 새 DB를 보도록 바꾸어 주어야 합니다. 

여기까지에서 시간이 촉박하여 실제 시도는 중단하였습니다. php 언어를 학습해야 하기 때문에..

**현재 테스트 환경에서 시도한 최선은 read replica 를 증설하여 읽기 성능을 향상한 것입니다.**
