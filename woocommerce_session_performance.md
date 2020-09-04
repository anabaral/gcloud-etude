# Wordpress Woocommerce 에서 세션 성능 증가 노력

현재까지의 결론:
* Redis Object Cache 플러그인을 쓰고 있는데, 그것이 유효하게 도움이 된다.
* WooCommerce가 세션을 DB에 저장하고 있는 근원적인 문제를 해결해 보려 했지만 그것은 한계가 있는 듯 하다.

지금까지 찾아온 것들을 차례로 적어 봅니다.

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

몇몇 플러그인들이 세션 사용에 관한 개선을 주장하는데, woocommerce 의 세션을 개선하는 것은 아닌 것 같습니다.

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
**google cloud sql 은 메모리 엔진을 지원하지 않습니다.**

결국 하려면 세션관리용 mysql을 별도로 설치해서 메모리 엔진 테이블을 생성해야 하는데
이게 가능하려면 위의 소스 ```class-wc-session-handler.php``` 를 고쳐 세션에 한해서는 새로운 DB를 보도록 바꾸어야 합니다. 

다시 확인해 본 바로는 **MEMORY 엔진은 BLOB/TEXT 컬럼을 지원하지 않습니다.** 즉 longtext 컬럼을 갖고 있는 한 이 역시 대안이 될 수 없습니다.

## Redis Object Cache 의 쓸모

앞서까지는 근원적인 해결이 안된다는 것을 설명했습니다만, 사실 서버가 가지고 있던 문제는 다른 게 아니었습니다.

* 위의 ```class-wc-session-handler.php``` 를 보면 내용이 변경될 때 DB를 쓰긴 하지만 대부분 '캐시'를 참조하고 있다는 사실을 확인할 수 있습니다.
* 그리고 그 캐시는, 조금 더 들여다 보면 ( wordpress 내부의 ```wp-includes/cache.php```, ```wp-includes/class-wp-object-cache.php``` 등) 일정한 규칙을 따릅니다.
  - 외부 제공 object-cache.php 가 wp-content 디렉터리에서 발견되면 그 캐시를 사용함
  - 없을 때는 그냥 내부 변수 (array 내지 hash 같은) 를 사용하여 캐시 역할을 수행함
* 즉 진짜 문제는 내부 변수를 사용한 단순한 캐시의 사용이었습니다. <br>
  그러면 인스턴스가 여럿으로 늘어난다고 값을 잃지는 않겠지만 요청이 여러 서버로 전달되면서 같은 내용을 중복해서 갖고 있게 됩니다. <br>
  사용자가 늘어나면 불필요한 메모리 사용량이 늘게 되는데(캐시를 적절히 버리는 보완로직도 없음) 메모리 부족은 성능에 영향을 줍니다.
* Kubernetes POD 위에 뜨므로 심하게는 반복적 OOMKilled 같은 현상을 만나게 될 수도 있습니다.

이것을 해소하려면 별도의 메모리를 둔 object cache가 존재하는 것이 좋습니다.
그리고 우리는 이미 Redis Object Cache 를 설치하고 별도의 Redis 서버에 연결해 둔 상태입니다.

문제는 이미 해결되어 있었습니다.



