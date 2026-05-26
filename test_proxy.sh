#!/bin/bash

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=================================================="
echo "    RHEL Proxy & Network Diagnostics Tool         "
echo "=================================================="

# 1. 환경 변수 체크
echo -e "\n[1] Checking Proxy Environment Variables..."
PROXY_URL=""
if [ -z "$http_proxy" ] && [ -z "$HTTP_PROXY" ]; then
    echo -e "${RED}[-] http_proxy is NOT set.${NC}"
else
    PROXY_URL=${http_proxy:-$HTTP_PROXY}
    echo -e "${GREEN}[+] http_proxy is set: $PROXY_URL${NC}"
fi

if [ -z "$https_proxy" ] && [ -z "$HTTPS_PROXY" ]; then
    echo -e "${RED}[-] https_proxy is NOT set.${NC}"
else
    echo -e "${GREEN}[+] https_proxy is set: ${https_proxy:-$HTTPS_PROXY}${NC}"
fi

# 프록시 URL에서 IP와 Port 파싱 (ex: http://10.10.10.18:9090 -> 10.10.10.18 / 9090)
if [ ! -z "$PROXY_URL" ]; then
    PROXY_IP=$(echo "$PROXY_URL" | sed -e 's/http:\/\///g' -e 's/https:\/\///g' | cut -d: -f1)
    PROXY_PORT=$(echo "$PROXY_URL" | sed -e 's/http:\/\///g' -e 's/https:\/\///g' | cut -d: -f2 | cut -d/ -f1)
fi

# 2. Google.com 아웃바운드 인터넷 통신 검증
echo -e "\n[2] Testing Internet Connectivity (google.com)..."
INTERNET_STATUS="OK"

HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 http://www.google.com)
HTTPS_CODE=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 https://www.google.com)

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 301 ] || [ "$HTTP_CODE" -eq 302 ]; then
    echo -e "${GREEN}[+] HTTP Connection to google.com: SUCCESS (Status: $HTTP_CODE)${NC}"
else
    echo -e "${RED}[-] HTTP Connection to google.com: FAILED (Status: $HTTP_CODE)${NC}"
    INTERNET_STATUS="FAIL"
fi

if [ "$HTTPS_CODE" -eq 200 ] || [ "$HTTPS_CODE" -eq 301 ] || [ "$HTTPS_CODE" -eq 302 ]; then
    echo -e "${GREEN}[+] HTTPS Connection to google.com: SUCCESS (Status: $HTTPS_CODE)${NC}"
else
    echo -e "${RED}[-] HTTPS Connection to google.com: FAILED (Status: $HTTPS_CODE)${NC}"
    INTERNET_STATUS="FAIL"
fi


# 3. 네트워크 및 게이트웨이 심층 진단 (인터넷 실패 시에만 실행하거나 상시 진단용)
if [ "$INTERNET_STATUS" = "FAIL" ]; then
    echo -e "\n${YELLOW}[!] Internet connection failed. Starting Deep Network Diagnostics...${NC}"
    
    # 3-1. 로컬 게이트웨이 체크
    GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -n 1)
    echo -e "\n[Diagnostic-1] Checking Default Gateway ($GATEWAY_IP)..."
    if [ ! -z "$GATEWAY_IP" ]; then
        ping -c 2 -W 2 $GATEWAY_IP > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[+] Ping to Default Gateway ($GATEWAY_IP): SUCCESS${NC}"
            echo -e "    -> 로컬 네트워크 카드(NIC) 및 기본 게이트웨이 장비는 정상 작동 중입니다."
        else
            echo -e "${RED}[-] Ping to Default Gateway ($GATEWAY_IP): FAILED${NC}"
            echo -e "${YELLOW}    -> [경고] 로컬 네트워크 연결 끊김 또는 게이트웨이 다운 가능성이 높습니다.${NC}"
        fi
    else
        echo -e "${RED}[-] Default Gateway IP could not be found in routing table.${NC}"
    fi

    # 3-2. 프록시 서버 호스트 및 포트 대기 상태 체크
    if [ ! -z "$PROXY_IP" ] && [ ! -z "$PROXY_PORT" ]; then
        echo -e "\n[Diagnostic-2] Checking Proxy Server ($PROXY_IP) and Port ($PROXY_PORT)..."
        
        # 프록시 서버 Ping 테스트
        ping -c 2 -W 2 $PROXY_IP > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[+] Ping to Proxy Server ($PROXY_IP): SUCCESS${NC}"
        else
            echo -e "${YELLOW}[!] Ping to Proxy Server ($PROXY_IP): FAILED (ICMP 차단일 수 있음)${NC}"
        fi

        # 프록시 서버 TCP 포트 오픈 테스트 (nc/telnet 없이 bash 내장 기능 사용)
        timeout 3 bash -c "cat < /dev/null > /dev/tcp/$PROXY_IP/$PROXY_PORT" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[+] TCP Connection to Proxy Port ($PROXY_PORT): SUCCESS${NC}"
            echo -e "    -> 프록시 서버 호스트 및 서비스 포트($PROXY_PORT)가 살아있습니다."
            echo -e "    -> 외부 방화벽 단에서 google.com으로 나가는 아웃바운드가 차단되었을 확률이 높습니다."
        else
            echo -e "${RED}[-] TCP Connection to Proxy Port ($PROXY_PORT): FAILED${NC}"
            echo -e "${RED}    -> [원인 발견] 프록시 서버에서 포트가 닫혀있거나, 로컬에서 프록시 서버로 가는 방화벽(ACL) 포트가 차단되었습니다.${NC}"
        fi
    fi

    # 3-3. DNS 정상 작동 여부 체크
    echo -e "\n[Diagnostic-3] Checking DNS Resolution..."
    host www.google.com > /dev/null 2>&1 || nslookup www.google.com > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] DNS Resolution for google.com: SUCCESS${NC}"
    else
        echo -e "${RED}[-] DNS Resolution for google.com: FAILED${NC}"
        echo -e "${YELLOW}    -> 네임서버(/etc/resolv.conf) 설정을 확인하십시오.${NC}"
    fi

else
    echo -e "\n${GREEN}[+] All internet connections via proxy are working perfectly. No diagnostics needed.${NC}"
fi

echo -e "\n=================================================="
