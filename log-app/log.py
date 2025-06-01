from mitmproxy import http
import json
import datetime
import os

def get_last_log_filename():
    if not os.path.exists("loghistory.txt"):
        return None
    with open("loghistory.txt", "r") as f:
        lines = f.readlines()
        if not lines:
            return None
        return lines[-1].strip()  

def request(flow: http.HTTPFlow) -> None:
    log_file = get_last_log_filename()
    if not log_file:
        log_file = "./logs/requests_default.json"  

    client_ip, client_port = flow.client_conn.peername
    timestamp = datetime.datetime.fromtimestamp(flow.request.timestamp_start).isoformat()

    request_data = {
        "timestamp": timestamp,
        "client_ip": client_ip,
        "method": flow.request.method,
        "url": flow.request.url,
        "headers": dict(flow.request.headers),
        "body": flow.request.get_text()
    }

    with open(log_file.replace(".json", "_requests.json"), "a") as f:
        f.write(json.dumps(request_data, ensure_ascii=False, indent=4) + "\n")

def response(flow: http.HTTPFlow) -> None:
    log_file = get_last_log_filename()
    if not log_file:
        log_file = "./logs/responses_default.json"  

    client_ip, _ = flow.client_conn.peername
    timestamp = datetime.datetime.fromtimestamp(flow.response.timestamp_start).isoformat()

    response_data = {
        "timestamp": timestamp,
        "client_ip": client_ip,
        "url": flow.request.url,
        "status_code": flow.response.status_code
    }

    with open(log_file.replace(".json", "_responses.json"), "a") as f:
        f.write(json.dumps(response_data, ensure_ascii=False, indent=4) + "\n")