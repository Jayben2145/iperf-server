# Multi-instance iperf3 on Windows (with HAProxy)

Spin up multiple iperf3 servers on incremental ports, run them as Windows services with NSSM, and front them with one HAProxy listener.

## Quick start
1) Download binaries  
   - iperf3 for Windows: https://iperf.fr/iperf-download.php (e.g., `C:\iperf3\iperf3.exe`)  
   - NSSM: https://nssm.cc/download (e.g., `C:\nssm\nssm.exe`)  
   - HAProxy for Windows: https://www.haproxy.org/  
2) From an elevated PowerShell in this folder, install services (edit paths/ports/count):
```powershell
powershell -ExecutionPolicy Bypass -File .\install-iperf-services.ps1 `
  -Count 20 `
  -StartPort 5000 `
  -IperfPath "C:\iperf3\iperf3.exe" `
  -NssmPath "C:\nssm\nssm.exe" `
  -LogDir "C:\iperf3\logs"
```
3) Place `haproxy.cfg` next to `haproxy.exe` (or anywhere you prefer).
4) Start HAProxy using the config: `haproxy.exe -f haproxy.cfg`

## Files
- `install-iperf-services.ps1` — creates services `iperf3-<port>` with NSSM, rotates logs, opens firewall for the port range, and starts them.
- `haproxy.cfg` — TCP load balancer listening on one port and proxying to the iperf3 instances.
- `nginx-iperf.conf` — legacy example if you build Nginx with the stream module.

## HAProxy wiring
- In `haproxy.cfg`, adjust:  
  - `bind *:5201` → change if you want a different public port.  
  - The `backend iperf_back` server list → match the ports created by the script (defaults: 5000-5019).  
- Start or reload HAProxy (example):
```
haproxy.exe -f haproxy.cfg
```

## Service management
- Check status: `Get-Service iperf3-*`
- Stop/start one: `Stop-Service iperf3-5003` / `Start-Service iperf3-5003`
- Re-run the install script to recreate/refresh the set (it removes same-name services first).

## Notes
- Clients connect only to the single HAProxy listen port; HAProxy distributes sessions across backends.  
- Config is TCP-only by default. If you need UDP tests, HAProxy can do UDP via `mode udp` and `dgram` sockets (different config).  
- Keep `-Count`/`-StartPort` in sync between the PowerShell script and the HAProxy backend list.  
- Logs live in `-LogDir`; NSSM rotation is enabled by default.

## Step-by-step (from zero)
1) Download/extract iperf3 to `C:\iperf3\iperf3.exe`.  
2) Download/extract NSSM to `C:\nssm\nssm.exe`.  
3) Download/extract HAProxy for Windows (zip from https://www.haproxy.org/).  
4) Place `haproxy.cfg` in the same folder as `haproxy.exe` (or update the path in the startup command).  
5) Decide how many iperf3 instances you want and what port range (e.g., 20 instances starting at 5000 → ports 5000-5019).  
6) Open an elevated PowerShell in this folder and run:
```powershell
powershell -ExecutionPolicy Bypass -File .\install-iperf-services.ps1 `
  -Count 20 `
  -StartPort 5000 `
  -IperfPath "C:\iperf3\iperf3.exe" `
  -NssmPath "C:\nssm\nssm.exe" `
  -LogDir "C:\iperf3\logs"
```
7) Edit `haproxy.cfg` backend list to match the ports you just created (5000-5019 in the example) and set the public `bind` port you want (defaults to 5201).  
8) Start HAProxy: `haproxy.exe -f haproxy.cfg`  
9) Verify services: `Get-Service iperf3-*` and confirm HAProxy is listening on your chosen port.  
10) Test from a client: `iperf3 -c <server-ip> -p <haproxy-bind-port>` (e.g., `-p 5201`).  
11) Adjust counts/ports later by rerunning the PowerShell script with new values and updating the HAProxy backend list accordingly.
