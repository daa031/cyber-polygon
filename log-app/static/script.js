const mitmForm = document.getElementById("mitmForm");
if (mitmForm) {
    mitmForm.addEventListener("submit", async (e) => {
        e.preventDefault();

        const formData = new FormData(e.target);
        const response = await fetch("/start_mitm", {
            method: "POST",
            body: formData
        });

        const data = await response.json();
        if (data.status === "started") {
            window.location.href = `/logs.html?log_file=${data.log_file}`;
        }
    });
}

if (window.location.pathname.includes("logs.html")) {
    const logOutput = document.getElementById("logOutput");
    const stopBtn = document.getElementById("stopBtn");
    const logFile = new URLSearchParams(window.location.search).get("log_file");

    const formatLog = (logText) => {
        try {
            const entries = logText.trim().split('\n');
            return entries.map(entry => {
                try {
                    const data = JSON.parse(entry);
                    return JSON.stringify(data, null, 2);
                } catch {
                    return entry;
                }
            }).join('\n\n');
        } catch {
            return logText;
        }
    };

    const updateLogs = async () => {
        try {
            const response = await fetch(`/get_logs/${logFile}`);
            const data = await response.json();
            
            if (data.status === "success") {
                let output = "=== REQUESTS ===\n";
                output += formatLog(data.requests) + "\n\n";
                output += "=== RESPONSES ===\n";
                output += formatLog(data.responses);
                
                logOutput.textContent = output;
                logOutput.scrollTop = logOutput.scrollHeight;
            }
        } catch (err) {
            console.error("Ошибка при получении логов:", err);
        }
        setTimeout(updateLogs, 1000);
    };

    updateLogs();

    if (stopBtn) {
        stopBtn.addEventListener("click", async () => {
            try {
                const response = await fetch("/stop_mitm", { method: "POST" });
                const result = await response.json();
                if (result.status === "stopped") {
                    window.location.href = `/download_logs/${logFile}`;
                }
            } catch (err) {
                console.error("Ошибка при остановке mitmproxy:", err);
            }
        });
    }
}