#!/bin/bash

manual() {
    echo -e "Usage: $0 -clients N -password SomePass -serverip 10.10.20.1/24 -externalip 192.168.63.169\n"
    echo "Аргументы:"
    echo "  -clients     Количество WireGuard клиентов"
    echo "  -password    Пароль для создания zip архива"
    echo "  -serverip    Внутренний IP адрес сервера с маской (например, 10.10.20.1/24)"
    echo "  -externalip  Внешний IP сервера (для подключения клиентов)"
    exit 1 
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -clients)
            CLIENTS=$2
            shift 2
            ;;
        -password)
            PASSWORD=$2
            shift 2
            ;;
        -serverip)
            SERVER_IP=$2
            shift 2
            ;;
        -externalip)
            EXTERNAL_IP=$2
            shift 2
            ;;
        *)
            manual
            ;;
    esac
done

if [[ -z "$CLIENTS" || -z "$PASSWORD" || -z "$SERVER_IP" || -z "$EXTERNAL_IP" ]]; then
    manual
fi

NETWORK_NUMBER=$(echo "$SERVER_IP" | awk -F. '{print $3}')
SERVER_PORT=$((51820 + NETWORK_NUMBER))

SERVER_KEYS_DIR="network${NETWORK_NUMBER}_keys"
CLIENT_CONFIG_DIR="network${NETWORK_NUMBER}_clients_configs"
SERVER_CONF="wg${NETWORK_NUMBER}.conf"

mkdir -p "$SERVER_KEYS_DIR" "$CLIENT_CONFIG_DIR"

wg genkey | tee "${SERVER_KEYS_DIR}/server${NETWORK_NUMBER}.private" | wg pubkey > "${SERVER_KEYS_DIR}/server${NETWORK_NUMBER}.public"

for CLIENT in $(seq 1 "$CLIENTS"); do
    CLIENT_PRIVATE_KEY_FILE="${SERVER_KEYS_DIR}/client${CLIENT}.private"
    CLIENT_PUBLIC_KEY_FILE="${SERVER_KEYS_DIR}/client${CLIENT}.public"

    wg genkey | tee "$CLIENT_PRIVATE_KEY_FILE" | wg pubkey > "$CLIENT_PUBLIC_KEY_FILE"

    CLIENT_CONF_FILE="${CLIENT_CONFIG_DIR}/client${CLIENT}_server${NETWORK_NUMBER}.conf"

    cat <<EOF > "$CLIENT_CONF_FILE"
[Interface]
PrivateKey = $(cat "$CLIENT_PRIVATE_KEY_FILE")
Address = 10.10.${NETWORK_NUMBER}.$((CLIENT + 1))/32
DNS = 1.1.1.1

[Peer]
PublicKey = $(cat "${SERVER_KEYS_DIR}/server${NETWORK_NUMBER}.public")
Endpoint = ${EXTERNAL_IP}:${SERVER_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
done

echo -e "1. Установить wireguard ('sudo apt install wireguard -y') \n\n2. Перенести конфиг в /etc/wireguard \n\n3. Включить соединение: sudo wg-quick up client3_server${NETWORK_NUMBER} \n\n4. Выключить соединение: sudo wg-quick down client3_server${NETWORK_NUMBER} \n\n5. Проверить статус: sudo wg \n\n" > "${CLIENT_CONFIG_DIR}/README"

zip -r -P "$PASSWORD" "network${NETWORK_NUMBER}_clients_configs.zip" "$CLIENT_CONFIG_DIR" >/dev/null
chmod 666 "network${NETWORK_NUMBER}_clients_configs.zip"

rm -rf "$CLIENT_CONFIG_DIR"

cat <<EOF > "$SERVER_CONF"
[Interface]
PrivateKey = $(cat "${SERVER_KEYS_DIR}/server${NETWORK_NUMBER}.private")
Address = ${SERVER_IP}
ListenPort = ${SERVER_PORT}
PostUp = iptables -A FORWARD -i wg${NETWORK_NUMBER} -j ACCEPT; iptables -t nat -A POSTROUTING -o ens33 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg${NETWORK_NUMBER} -j ACCEPT; iptables -t nat -D POSTROUTING -o ens33 -j MASQUERADE

EOF

for CLIENT in $(seq 1 "$CLIENTS"); do
    CLIENT_PUBLIC_KEY=$(cat "${SERVER_KEYS_DIR}/client${CLIENT}.public")
    cat <<EOF >> "$SERVER_CONF"
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 10.10.${NETWORK_NUMBER}.$((CLIENT + 1))/32
EOF
done

cat <<EOF > "setup_server_${NETWORK_NUMBER}.txt"
Настройка сервера WireGuard (wg${NETWORK_NUMBER}):

1. Установите WireGuard:
   sudo apt update && sudo apt install wireguard iptables -y

2. Включите переадресацию пакетов:
   echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p

3. Разместите конфиг:
   sudo cp wg${NETWORK_NUMBER}.conf /etc/wireguard/
   sudo chmod 600 /etc/wireguard/wg${NETWORK_NUMBER}.conf

4. Запустите VPN:
   sudo wg-quick up wg${NETWORK_NUMBER}

5. Проверьте статус:
   sudo wg

6. Откройте порт ${SERVER_PORT}/udp в фаерволе:
   sudo ufw allow ${SERVER_PORT}/udp
EOF

echo "Готово. Созданы конфигурации для сети ${NETWORK_NUMBER}:"
echo "- Серверный конфиг: $SERVER_CONF"
echo "- Архив клиентских конфигов: network${NETWORK_NUMBER}_clients_configs.zip"
echo "- Инструкция по настройке сервера: setup_server_${NETWORK_NUMBER}.txt"
