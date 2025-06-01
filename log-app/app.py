import os
import random
import subprocess
import zipfile
from flask import Flask, render_template, request, jsonify, send_from_directory

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['LOG_FOLDER'] = 'logs'
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(app.config['LOG_FOLDER'], exist_ok=True)

mitm_process = None

def append_to_loghistory(log_name):
    log_entry = f"./logs/{log_name}.json"
    with open("loghistory.txt", "a") as f:
        f.write(log_entry + "\n")
    return log_entry

def get_log_path(log_name):
    return os.path.join(app.config['LOG_FOLDER'], log_name)

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/start_mitm", methods=["POST"])
def start_mitm():
    global mitm_process

    target_url = request.form.get("target_url")
    cert_file = request.files.get("cert_file")
    listen_port = request.form.get("listen_port")
    log_filename = request.form.get("log_filename")

    cert_path = None
    if cert_file and cert_file.filename:
        cert_path = os.path.join(app.config['UPLOAD_FOLDER'], "cert_key.pem")
        cert_file.save(cert_path)

    random_suffix = random.randint(10000000, 99999999)
    final_log_name = f"{log_filename}_{random_suffix}"
    append_to_loghistory(final_log_name)

    command = [
        "mitmdump",
        "--mode", f"reverse:{target_url}",
        "--listen-port", listen_port,
        "--ssl-insecure",
        "-s", "./log.py"
    ]

    if cert_path:
        command.extend(["--certs", f"*={cert_path}"])

    print("Запускаем команду:", " ".join(command))
    mitm_process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    if mitm_process.poll() is None:
        print(f"mitmdump успешно запущен (PID: {mitm_process.pid})")
    else:
        print("Ошибка запуска mitmdump!")
        
    return jsonify({
        "status": "started",
        "log_file": final_log_name
    })

@app.route("/stop_mitm", methods=["POST"])
def stop_mitm():
    global mitm_process
    if mitm_process:
        mitm_process.terminate()
        mitm_process = None
    return jsonify({"status": "stopped"})

@app.route("/get_logs/<log_name>")
def get_logs(log_name):
    base_path = get_log_path(log_name)
    
    def read_log_file(path):
        if os.path.exists(path):
            with open(path, 'r') as f:
                return f.read()
        return ""

    requests_log = read_log_file(f"{base_path}_requests.json")
    responses_log = read_log_file(f"{base_path}_responses.json")

    return jsonify({
        "status": "success",
        "requests": requests_log,
        "responses": responses_log
    })

@app.route("/download_logs/<log_name>")
def download_logs(log_name):
    base_path = get_log_path(log_name)
    zip_filename = f"{log_name}_logs.zip"
    zip_path = get_log_path(zip_filename)

    with zipfile.ZipFile(zip_path, 'w') as zipf:
        requests_file = f"{base_path}_requests.json"
        if os.path.exists(requests_file):
            zipf.write(requests_file, "requests.json")
        
        responses_file = f"{base_path}_responses.json"
        if os.path.exists(responses_file):
            zipf.write(responses_file, "responses.json")

    return send_from_directory(
        app.config['LOG_FOLDER'],
        zip_filename,
        as_attachment=True
    )

@app.route("/logs.html")
def logs_page():
    log_file = request.args.get("log_file")
    return render_template("logs.html", log_file=log_file)

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)