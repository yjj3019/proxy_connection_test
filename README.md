# proxy_connection_test

인프라 아키텍처 기반 장애 격리 (Fault Isolation)
네트워크와 게이트웨이 문제를 체계적으로 분류하기 위해 OSI 7 Layer 및 실제 라우팅 경로에 따라 로컬 NIC 상태, 기본 게이트웨이(Default Gateway) 연결성, 프록시 서버 TCP 포트 대기 상태, 외부 도메인(DNS) 해석의 4단계 카테고리로 나누어 진단 로직을 추가했습니다.

1. 로컬 링크 및 기본 게이트웨이 검증 (Local Network & Gateway)
RHEL 시스템의 라우팅 테이블(ip route)에서 기본 게이트웨이 IP를 자동으로 추출합니다.

게이트웨이로 ping을 보내 로컬 스위치 및 물리 케이블 단의 연결성에 문제가 없는지 확인합니다. (ICMP 차단 환경 감안 유무 체크)

2. 프록시 서버 호스트 및 포트 검증 (Proxy Host & Port)
설정된 프록시 주소(10.10.10.18)로의 IP 레이어 연결성을 체크합니다.

프록시 서비스 포트(9090)가 살아있는지 bash 소켓(/dev/tcp/)을 이용해 3초 타임아웃으로 TCP 핸드셰이크를 시도합니다. 이 단계에서 '네트워크 경로 문제'와 '프록시 서비스 다운'을 명확히 격리할 수 있습니다.

3. DNS/네임서버 및 아웃바운드 격리 (DNS & Internet Edge)
google.com 도메인이 정상적으로 IP로 변환되는지(DNS 작동 여부) 확인하여 내부 DNS 네임서버 문제를 감지합니다.

4. 개선 제안
ping 에 대한 보완 설명: 보안이 강화된 엔터프라이즈 사내 망 환경에서는 라우터(Gateway)나 프록시 인프라 서버가 내부 ping (ICMP) 요청을 거부하도록 드롭(Drop) 정책이 적용되어 있을 수 있습니다. 따라서 Ping to Proxy Server: FAILED가 뜨더라도, 뒤이어 실행되는 TCP Connection to Proxy Port가 SUCCESS라면 네트워크 선로 및 프록시 서비스는 완벽히 정상인 상태로 해석하시면 됩니다.

에러 상태 코드 다각화: 사내 방화벽 정책 중 웹 필터링(URL Filtering) 솔루션이 활성화되어 있을 경우 curl 결과가 403 Forbidden 혹은 503 Service Unavailable로 떨어질 수 있습니다. 스크립트 출력 결과의 Status: XXX 코드를 보고 사내 보안 장비에서 차단된 것인지 매핑해볼 수 있어 트러블슈팅이 더욱 명확해집니다.
