import http.server
import socketserver
import json
import psutil
import subprocess
import re
from urllib.parse import urlparse, parse_qs

PORT = 5000

class ProcessMonitorHandler(http.server.SimpleHTTPRequestHandler):
    # def get_compressed_memory_mb(pid):
    #     try:
    #         # Run the native macOS 'ps' command targeting the specific PID
    #         # 'cxmem' specifies compressed memory size
    #         cmd = ["ps", "-o", "cxmem=", "-p", str(pid)]
    #         output = subprocess.check_output(cmd).decode('utf-8').strip()
            
    #         if not output:
    #             return 0.0
                
    #         # macOS 'ps' outputs human-readable strings like '155M', '12K', or '4G'
    #         unit = output[-1].upper()
    #         value = float(output[:-1])
            
    #         if unit == 'K':
    #             return round(value / 1024, 2)
    #         elif unit == 'M':
    #             return round(value, 2)
    #         elif unit == 'G':
    #             return round(value * 1024, 2)
    #         else:
    #             # If no unit is present, it's typically bytes or standard pages
    #             return round(float(output) / (1024 * 1024), 2)
                
    #     except Exception:
    #         return 0.0  # Return 0 if the process died or command failed


    def do_GET(self):

        def get_detailed_compressed_mb(pid):
            try:
                # 'footprint' gathers exact physical footprint information
                cmd = ["sudo", "footprint", str(pid)]
                output = subprocess.check_output(cmd).decode('utf-8')
                
                # Look for the specific "phys_footprint" line in the footprint report
                # Example line: "phys_footprint: 45.2M (with 12.1M actual text/data...)"
                match = re.search(r"phys_footprint:\s+([\d.]+)\s*([KMG]B)?", output)
                if match:
                    value = float(match.group(1))
                    unit = match.group(2)
                    
                    if unit == 'KB': return round(value / 1024, 2)
                    if unit == 'MB': return round(value, 2)
                    if unit == 'GB': return round(value * 1024, 2)
                    return round(value / (1024 * 1024), 2)
                    
            except Exception:
                pass
            return 0.0

        parsed_url = urlparse(self.path)
        
        # API Route: Fetch all running processes for the dropdown list
        if parsed_url.path == '/api/processes':
            processes = []
            for proc in psutil.process_iter(['pid', 'name']):
                try:
                    processes.append(proc.info)
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    pass
            # Sort alphabetically by name
            processes.sort(key=lambda x: x['name'].lower() if x['name'] else '')
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(processes).encode('utf-8'))
            
        # API Route: Fetch specific memory usage for a given PID
        elif parsed_url.path == '/api/memory':
            query_components = parse_qs(parsed_url.query)
            pid = int(query_components.get("pid", [0])[0])
            
            data = {"success": False, "memory_mb": 0, "compressed_mb": 0, "error": ""}
            try:
                proc = psutil.Process(pid)
                
                # 1. Get Physical Resident RAM
                mem_info = proc.memory_info()
                data["memory_mb"] = get_detailed_compressed_mb(pid)
                

                data["success"] = True
            except psutil.NoSuchProcess:
                data["error"] = "Process ID not found."
            except psutil.AccessDenied:
                data["error"] = "Access Denied (Try running as Administrator/sudo)."
            except Exception as e:
                data["error"] = str(e)

                
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode('utf-8'))
            
        # Default Route: Serve the UI Layout
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode('utf-8'))

# Pure HTML / Vanilla JavaScript UI Template
# --- Replace the HTML_TEMPLATE variable in app.py with this version ---
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>System Process Memory Tracker</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #f3f4f6; margin: 0; padding: 20px; color: #333; }
        .container { max-width: 900px; margin: 0 auto; background: white; padding: 25px; border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.05); }
        h1 { margin-top: 0; color: #1e293b; font-size: 24px; }
        .selector-zone { display: flex; gap: 15px; margin-bottom: 20px; align-items: flex-end; flex-wrap: wrap; }
        .field-group { display: flex; flex-direction: column; gap: 5px; }
        label { font-size: 12px; font-weight: bold; color: #64748b; text-transform: uppercase; }
        select, input { padding: 10px; border: 1px solid #cbd5e1; border-radius: 4px; min-width: 200px; font-size: 14px; }
        button { padding: 10px 20px; font-size: 14px; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; background: #2563eb; color: white; height: 40px; }
        button:disabled { background: #cbd5e1; cursor: not-allowed; }
        .btn-stop { background: #dc2626; }
        .status-bar { display: flex; justify-content: space-between; background: #f8fafc; padding: 15px; border-radius: 6px; margin-bottom: 20px; border: 1px solid #e2e8f0; }
        .stat { font-size: 18px; font-weight: bold; color: #0f172a; }
        .error { color: #dc2626; font-weight: bold; margin-bottom: 15px; display: none; }
        .chart-wrapper { height: 400px; width: 100%; }
    </style>
</head>
<body>

<div class="container">
    <h1>OS Process Memory Tracker</h1>
    
    <div class="error" id="errorMsg"></div>

    <div class="selector-zone">
        <div class="field-group">
            <label>Pick Running Process</label>
            <select id="procSelect">
                <option value="">-- Select a process --</option>
            </select>
        </div>
        
        <div class="field-group">
            <label>Or enter PID manually</label>
            <input type="number" id="pidInput" placeholder="e.g. 12440">
        </div>

        <button id="startBtn">Track Process</button>
        <button id="stopBtn" class="btn-stop" disabled>Stop</button>
    </div>

    <div class="status-bar">
        <div>Tracking Target: <span id="targetLabel" class="stat">None</span></div>
        <div>Current Memory: <span id="memLabel" class="stat">0 MB</span></div>
    </div>

    <div class="chart-wrapper">
        <canvas id="liveChart"></canvas>
    </div>
</div>

<script>
    const procSelect = document.getElementById('procSelect');
    const pidInput = document.getElementById('pidInput');
    const startBtn = document.getElementById('startBtn');
    const stopBtn = document.getElementById('stopBtn');
    const errorMsg = document.getElementById('errorMsg');
    const targetLabel = document.getElementById('targetLabel');
    const memLabel = document.getElementById('memLabel');

    let intervalId = null;
    let targetPid = null;

    // Initialize Chart.js
    const ctx = document.getElementById('liveChart').getContext('2d');
    const liveChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Memory Usage (MB)',
                data: [],
                borderColor: '#2563eb',
                backgroundColor: 'rgba(37, 99, 235, 0.1)',
                borderWidth: 2,
                fill: true,
                tension: 0.2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: { 
                    title: { display: true, text: 'Timestamp (DD/MM HH:MM:SS)' },
                    ticks: { 
                        maxTicksLimit: 10, // Keeps x-axis from looking messy as time goes on
                        maxRotation: 45,   // Rotates timestamps slightly for cleaner spacing
                        minRotation: 45
                    }
                },
                y: { title: { display: true, text: 'RAM (MB)' }, beginAtZero: false }
            }
        }
    });

    // Helper function to build custom format string: DD/MM HH:MM:SS
    function getFormattedTimestamp() {
        const now = new Date();
        
        const day = String(now.getDate()).padStart(2, '0');
        const month = String(now.getMonth() + 1).padStart(2, '0'); // Months are 0-indexed
        
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        const seconds = String(now.getSeconds()).padStart(2, '0');
        
        return `${day}/${month} ${hours}:${minutes}:${seconds}`;
    }

    async function loadProcesses() {
        try {
            const res = await fetch('/api/processes');
            const processes = await res.json();
            processes.forEach(p => {
                const opt = document.createElement('option');
                opt.value = p.pid;
                opt.textContent = `${p.name} (PID: ${p.pid})`;
                procSelect.appendChild(opt);
            });
        } catch (err) {
            showError("Could not retrieve system process list.");
        }
    }

    procSelect.addEventListener('change', () => {
        if(procSelect.value) pidInput.value = procSelect.value;
    });

    function showError(msg) {
        errorMsg.textContent = msg;
        errorMsg.style.display = msg ? 'block' : 'none';
    }

    async function tick() {
        try {
            const res = await fetch(`/api/memory?pid=${targetPid}`);
            const data = await res.json();
            
            if (!data.success) {
                showError(data.error);
                stopTracking();
                return;
            }

            showError(""); 
            memLabel.textContent = `${data.memory_mb} MB`;
            
            // Get precise wall-clock timestamp string
            const timestamp = getFormattedTimestamp();

            liveChart.data.labels.push(timestamp);
            liveChart.data.datasets[0].data.push(data.memory_mb);
            
            liveChart.update('none');

        } catch (err) {
            showError("Lost connection to tracking backend.");
            stopTracking();
        }
    }

    function startTracking() {
        const pid = parseInt(pidInput.value);
        if (!pid) {
            alert("Please pick a process or provide a valid PID!");
            return;
        }

        targetPid = pid;
        
        const selectedOpt = Array.from(procSelect.options).find(o => o.value == pid);
        targetLabel.textContent = selectedOpt ? selectedOpt.textContent : `PID: ${pid}`;

        liveChart.data.labels = [];
        liveChart.data.datasets[0].data = [];
        liveChart.update();

        showError("");
        startBtn.disabled = true;
        stopBtn.disabled = false;
        procSelect.disabled = true;
        pidInput.disabled = true;

        // Poll every 5000 milliseconds (5 seconds)
        intervalId = setInterval(tick, 5000);
        tick();
    }

    function stopTracking() {
        clearInterval(intervalId);
        startBtn.disabled = false;
        stopBtn.disabled = true;
        procSelect.disabled = false;
        pidInput.disabled = false;
    }

    startBtn.addEventListener('click', startTracking);
    stopBtn.addEventListener('click', stopTracking);
    loadProcesses();
</script>
</body>
</html>
"""

if __name__ == '__main__':
    print(f"Starting tracking server at http://localhost:{PORT}")
    socketserver.TCPServer.allow_reuse_address = True  # <-- THE MAGIC LINE
    
    try:
        with socketserver.TCPServer(("", PORT), ProcessMonitorHandler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer shutting down gracefully.")