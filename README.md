# Multi-instance iperf3 on Windows (with Nginx proxy)

Spin up multiple iperf3 servers on incremental ports, run them as Windows services with NSSM, and front them with one Nginx listener.

## Quick start
1) Download binaries  
   - iperf3 for Windows: https://iperf.fr/iperf-download.php (e.g., `C:\iperf3\iperf3.exe`)  
   - NSSM: https://nssm.cc/download (e.g., `C:\nssm\nssm.exe`)  
   - Nginx for Windows with `stream` module: https://nginx.org/en/docs/windows.html  
2) From an elevated PowerShell in this folder, install services (edit paths/ports/count):
```powershell
powershell -ExecutionPolicy Bypass -File .\install-iperf-services.ps1 `
  -Count 20 `
  -StartPort 5000 `
  -IperfPath "C:\iperf3\iperf3.exe" `
  -NssmPath "C:\nssm\nssm.exe" `
  -LogDir "C:\iperf3\logs"
```
3) Copy `nginx-iperf.conf` into your Nginx include path (e.g., `conf.d/iperf/`), ensure `nginx.conf` includes it, and reload Nginx.

## Files
- `install-iperf-services.ps1` — creates services `iperf3-<port>` with NSSM, rotates logs, opens firewall for the port range, and starts them.
- `nginx-iperf.conf` — stream load balancer listening on one port and proxying to the iperf3 instances.

## Nginx wiring
- In `nginx.conf`, include the stream snippets:
```
stream {
    include conf.d/iperf/*.conf;
}
```
- In `nginx-iperf.conf`, adjust:  
  - `listen 5201 reuseport;` → change if you want a different public port.  b
  - `upstream iperf3_backend` servers → match the ports created by the script (defaults: 5000-5019).  
- Reload Nginx: `nginx -s reload`

## Service management
- Check status: `Get-Service iperf3-*`
- Stop/start one: `Stop-Service iperf3-5003` / `Start-Service iperf3-5003`
- Re-run the install script to recreate/refresh the set (it removes same-name services first).

## Notes
- Clients connect only to the single Nginx listen port; Nginx distributes sessions across backends.  
- Config is TCP-only by default. For UDP tests, add `udp` to the Nginx `listen` and backend definitions.  
- Keep `-Count`/`-StartPort` in sync between the PowerShell script and the Nginx upstream list.  
- Logs live in `-LogDir`; NSSM rotation is enabled by default.

## Step-by-step (from zero)
1) Download/extract iperf3 to `C:\iperf3\iperf3.exe`.  
2) Download/extract NSSM to `C:\nssm\nssm.exe`.  
3) Install Nginx for Windows and confirm it has the `stream` module (the official build does).  
4) Place `nginx-iperf.conf` under your Nginx include path (e.g., `C:\nginx\conf.d\iperf\nginx-iperf.conf`).  
5) In `nginx.conf`, inside or alongside the `stream {}` block, add `include conf.d/iperf/*.conf;` so this file is loaded.  
6) Decide how many iperf3 instances you want and what port range (e.g., 20 instances starting at 5000 → ports 5000-5019).  
7) Open an elevated PowerShell in this folder and run:
```powershell
powershell -ExecutionPolicy Bypass -File .\install-iperf-services.ps1 `
  -Count 20 `
  -StartPort 5000 `
  -IperfPath "C:\iperf3\iperf3.exe" `
  -NssmPath "C:\nssm\nssm.exe" `
  -LogDir "C:\iperf3\logs"
```
8) Edit `nginx-iperf.conf` upstream list to match the ports you just created (5000-5019 in the example) and set the public `listen` port you want (defaults to 5201).  
9) Reload Nginx: `nginx -s reload` (run from the Nginx install directory).  
10) Verify services: `Get-Service iperf3-*` and confirm Nginx is listening on your chosen port.  
11) Test from a client: `iperf3 -c <server-ip> -p <nginx-listen-port>` (e.g., `-p 5201`).  
12) Adjust counts/ports later by rerunning the PowerShell script with new values and updating the Nginx upstream list accordingly.
