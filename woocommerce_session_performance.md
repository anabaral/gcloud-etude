# Wordpress Woocommerce 에서 세션 성능 증가 노력

현재 실패상태이지만 지금까지 해온 노력을 적어 봅니다.

Wordpress 의 세션 관리와 별개로 woocommerce 는 별도로 세션을 관리하고 있습니다.

wordpress 는 apache+php 기반에서 구동되고 있습니다만, 코어 기능은 사실상 php에서 다음과 같이 즐겨 사용하는 세션 사용 패턴을 **쓰지 않는다고** 합니다. 
```
session_start();
...
$_SESSION["city"] = "부산";
```

(사실 소스를 뒤져 보면 몇몇 플러그인에서 사용하긴 함)

