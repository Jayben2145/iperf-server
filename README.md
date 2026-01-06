# Multi-instance iperf3 on Windows (with Nginx stream)

Run multiple iperf3 servers on incremental ports as Windows services and front them with a single Nginx `stream` listener.

## Quick start
1) Download binaries  
   - iperf3 for Windows: https://iperf.fr/iperf-download.php (e.g., `C:\iperf3\iperf3.exe`)  
   - NSSM: https://nssm.cc/download (e.g., `C:\nssm\nssm.exe`)  
   - Nginx with the `stream` module enabled  
2) From an elevated PowerShell in this folder, install services (edit paths/ports/count):
```powershell
powershell -ExecutionPolicy Bypass -File .\install-iperf-services.ps1 `
  -Count 20 `
  -StartPort 5000 `
  -IperfPath "C:\iperf3\iperf3.exe" `
  -NssmPath "C:\nssm\nssm.exe" `
  -LogDir "C:\iperf3\logs"
```
3) Replace your Nginx config with `nginx.conf` (or merge its contents into your existing config).  
4) Reload Nginx.

## Files
- `install-iperf-services.ps1` — creates services `iperf3-<port>` with NSSM, rotates logs, opens firewall for the port range, and starts them.
- `nginx.conf` — full Nginx config for stream proxying to iperf3 instances.
- `nginx-iperf.conf` — earlier stream snippet (keep if you prefer include-style config).

## Nginx configuration
- `nginx.conf` is a full config you can drop into `conf/nginx.conf`.
- If you already have a working `nginx.conf`, copy the `stream { ... }` block from `nginx.conf` into yours.
- In `nginx.conf`, update:  
  - `listen 5201;` → set the public port clients will connect to.  
  - `server 127.0.0.1:5000` … → match the ports created by the script (defaults: 5000-5019).  

## Service management
- Check status: `Get-Service iperf3-*`
- Stop/start one: `Stop-Service iperf3-5003` / `Start-Service iperf3-5003`
- Re-run the install script to recreate/refresh the set (it removes same-name services first).

## Notes
- Clients connect only to the single Nginx listen port; Nginx distributes sessions across backends.  
- Config is TCP-only by default. For UDP tests, add `udp` to the `listen` and backend definitions.  
- Keep `-Count`/`-StartPort` in sync between the PowerShell script and the Nginx upstream list.  
- Logs live in `-LogDir`; NSSM rotation is enabled by default.

## Step-by-step (from zero)
1) Download/extract iperf3 to `C:\iperf3\iperf3.exe`.  
2) Download/extract NSSM to `C:\nssm\nssm.exe`.  
3) Install Nginx with the `stream` module enabled.  
4) Place `nginx.conf` at `C:\nginx\conf\nginx.conf` (or merge the `stream` block into your existing config).  
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
7) Edit `nginx.conf` upstream list to match the ports you created and set the `listen` port you want (defaults to 5201).  
8) Reload Nginx: `nginx -s reload` (run from the Nginx install directory).  
9) Verify services: `Get-Service iperf3-*` and confirm Nginx is listening on your chosen port.  
10) Test from a client: `iperf3 -c <server-ip> -p <nginx-listen-port>` (e.g., `-p 5201`).  
11) Adjust counts/ports later by rerunning the PowerShell script with new values and updating `nginx.conf` accordingly.
