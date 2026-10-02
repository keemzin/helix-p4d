# Perforce Helix P4D Server in Docker

A production-ready containerized Perforce Helix Core (P4D) server running on native Ubuntu 24.04 (Noble) using the official Perforce APT packages (`helix-p4d` and `helix-swarm-triggers`).

- **Pre-built Image:** [`johnsdoes/helix-p4d:2026.1`](https://hub.docker.com/r/johnsdoes/helix-p4d) (Available directly on Docker Hub)
- **Built-in Tools:** `helix-p4d`, `helix-swarm-triggers`, `nano`, `vim-tiny`, `openssl`
- **Architectures:** Linux AMD64 (x86_64)

---

## Deployment Options

### Option A: Standard Local / LAN Deployment (`docker-compose.yml`)

Use this for local development, home lab, or trusted internal network setups where port `1666` is published.

#### 1. Configure Environment
Copy the sample environment file and configure your credentials:
```bash
cp .env.example .env
```

#### 2. Start the Server
```powershell
# Quick deploy using pre-built image:
docker compose up -d

# Or build locally from source:
docker compose up -d --build
```

#### 3. View Server Logs
```powershell
docker compose logs -f
```

---

### Option B: Tailscale-Secured Remote Deployment (`docker-compose.tailscale.yml`)

Use this setup on Synology NAS, Portainer, or cloud VPS to allow remote team members to connect securely over [Tailscale](https://tailscale.com) without opening or publishing any ports to the LAN or public internet.

```
                        HOW EVERYONE CONNECTS
 ┌──────────────────────────────────────────────────────────────────┐
 │                                                                  │
 │   LOCAL USER (in office / home LAN)                              │
 │   P4V → 192.168.x.x:1666       user: admin / local_dev           │
 │                                                                  │
 │   REMOTE USER (anywhere, with Tailscale)                         │
 │   P4V → 100.x.x.x:1666         user: remote_dev                  │
 │                                                                  │
 └──────────────────────────────────────────────────────────────────┘
          │ LAN                                   │ Internet
          │                                       │ (encrypted by Tailscale)
          ▼                                       ▼
 ┌─ HOST / SYNOLOGY NAS ────────────────────────────────────────────┐
 │                                                                  │
 │   (Optional: port 1666     ┌── p4-tailscale container ────────┐  │
 │    on LAN if published)    │ Tailscale node: p4-synology      │  │
 │          │                 │ tailnet IP: 100.x.x.x            │  │
 │          │                 │                                  │  │
 │          │                 │ serve rule:                      │  │
 │          │                 │ tcp 1666 → helix-p4d:1666        │  │
 │          │                 └───────────────┬──────────────────┘  │
 │          │                                 │                     │
 │          └──────────────┬──────────────────┘                     │
 │                         ▼    (Internal Docker network)           │
 │            ┌── helix-p4d container ───────────────┐              │
 │            │ Perforce server, listens on 1666     │              │
 │            │                                      │              │
 │            │ /root         live db tables         │              │
 │            │ /depots       versioned assets       │              │
 │            │ /checkpoints  backups                │              │
 │            └──────────────────────────────────────┘              │
 │                                                                  │
 │   depots on disk / NAS: /volume2/P4ROOT_DCKR or ./depots         │
 └──────────────────────────────────────────────────────────────────┘
```

#### Tailscale Access Matrix
| Attribute | Local User (LAN) | Remote User (Tailscale) |
| :--- | :--- | :--- |
| **Address** | `192.168.x.x:1666` (if port published) | `100.x.x.x:1666` (Tailnet IP) |
| **Path** | LAN → Published port → `p4d` | Tailscale → Serve rule → `p4d` |
| **Requirements** | LAN access | Tailscale client + node share |
| **P4 Login** | `admin` / `local_dev` | `remote_dev` / `alice` |
| **Host DSM / SMB** | Accessible on LAN | **Inaccessible** (restricted to port 1666) |

#### Deploying with Tailscale

Deploy via Docker Compose:
```bash
docker compose -f docker-compose.tailscale.yml up -d
```

*(If deploying via Portainer on Synology, paste `docker-compose.tailscale.yml` into the Portainer Stack editor and set your environment variables).*

#### Tailscale First-Time Activation
1. **Open a shell in the Tailscale container:**
   ```bash
   docker exec -it p4-tailscale sh
   ```
2. **Authenticate with Tailscale:**
   ```bash
   tailscale up
   ```
   Open the printed authentication URL in your browser and approve the device.
3. **Verify Tailscale connection:**
   ```bash
   tailscale status
   tailscale ip -4
   ```
4. **Configure TCP Forwarding to P4D:**
   ```bash
   tailscale serve reset
   tailscale serve --bg --tcp 1666 tcp://helix-p4d:1666
   tailscale serve status
   ```
5. **Disable Key Expiry:** In the Tailscale Admin Console, go to **Machines** → `p4-synology` → `...` menu → select **Disable Key Expiry** so the node remains connected permanently.
   > The Tailscale login state and serve rules persist in the `ts_state` volume across container updates and host reboots.

---

## 3-Tier Storage Architecture

Perforce data is decoupled into three distinct tiers for maximum performance, data integrity, and host backup convenience:

| Storage Name | Container Mount Target | Type | What Lives Here | Why |
| :--- | :--- | :--- | :--- | :--- |
| **`P4_P4ROOT`** | `/opt/perforce/p4/home/root` | Named Volume | Live `db.*` tables, active journal, `p4dctl` configs, `server.id`, logs | Native Linux ext4 performance and strict POSIX file-locking required by database tables. |
| **`P4_CKP`** | `/opt/perforce/p4/home/checkpoints` | Named Volume | Checkpoint archives (`*.ckp.*.gz`) and rotated journals | Safe database backup dumps created by `p4 admin checkpoint`. |
| **`./depots`** | `/opt/perforce/p4/home/depots` | Host Bind Mount | Versioned files, archives (`*,v`), assets | Easily accessible directly on host storage or NAS (`P4DEPOTS_PATH`). |

> [!CAUTION]
> Never bind-mount the live database (`P4_P4ROOT`) directly to a Windows NTFS folder on Docker Desktop. NTFS-to-Linux filesystem translation (9P/VirtioFS) causes high I/O latency and risks POSIX database lock failures. Keep `P4_P4ROOT` on a Docker named volume!

---

## Connecting to the Server

### 1. From Host or Client Workstations
* **Using P4V (Perforce Visual Client):**
  * **Server:** `localhost:1666` (or `100.x.x.x:1666` for Tailscale)
  * **User:** `admin` (or user specified in `.env`)
  * **Password:** your configured password
* **Using Windows / macOS / Linux `p4` CLI:**
  ```powershell
  p4 -p localhost:1666 -u admin info
  p4 -p localhost:1666 -u admin login
  ```

### 2. Inside the Container
Bash into the running server container:
```powershell
docker compose exec -it p4d bash
```
Authenticate inside the container:
```bash
echo "$P4PASSWD" | p4 login
```

---

## Built-in Form Editors (`nano` & `vi`)

The image includes both **`nano`** (default) and **`vi`** (`vim-tiny`). 

The environment variable `P4EDITOR=nano` is pre-configured. Perforce form commands will open directly in `nano`:
* `p4 client` (client workspaces)
* `p4 user` (user accounts)
* `p4 protect` (permissions & access tables)
* `p4 triggers` (triggers configuration)
* `p4 change` (changelist specifications)

To use `vi` instead, set `P4EDITOR=vi` in your `.env` file.

---

## Configuration Reference (`.env`)

| Variable | Default | Description |
| :--- | :--- | :--- |
| `NAME` | `perforce-server` | Service instance name (ServerID) |
| `P4NAME` | `master` | Logical server name |
| `P4TCP` | `1666` | TCP port the server listens on |
| `P4PORT` | `1666` | Connection port used by `p4` client (`ssl:1666` for SSL) |
| `P4USER` | `admin` | Initial super-user username |
| `P4PASSWD` | `pass12349ers` | Initial super-user password |
| `P4CASE` | `-C0` | Case sensitivity (`-C0` = sensitive, `-C1` = insensitive) |
| `P4CHARSET` | `utf8` | Server character set (Unicode mode) |
| `JNL_PREFIX` | `perforce-server` | Checkpoint and journal prefix |
| `P4DEPOTS_PATH` | `./depots` | Host directory or NAS path for versioned depot files |
| `P4EDITOR` | `nano` | Default CLI editor (`nano` or `vi`) |

---

## Common Administration Tasks

### 1. Database Checkpoints (Live Backups)
Take a live database snapshot safely while the server is active:
```powershell
# Standard uncompressed checkpoint:
docker compose exec p4d p4 admin checkpoint

# Or gzip-compressed checkpoint (recommended):
docker compose exec p4d p4 admin checkpoint -z
```

#### Verifying Checkpoints
List the contents of the `P4_CKP` backup volume:
```powershell
docker compose exec p4d ls -lh /opt/perforce/p4/home/checkpoints
```
You will find:
* `perforce-server.ckp.<N>` (or `.ckp.<N>.gz`): The database snapshot.
* `perforce-server.ckp.<N>.md5`: MD5 checksum verifying backup integrity.
* `perforce-server.jnl.<N-1>`: Rotated journal containing all transactions up to this checkpoint.

#### Offsite Backup Copies
Copy checkpoints to host storage:
```powershell
docker compose cp p4d:/opt/perforce/p4/home/checkpoints ./my-backups
```
Or stream archives to a remote backup destination:
```bash
docker compose exec p4d tar -czf - -C /opt/perforce/p4/home/checkpoints . | ssh user@remote_ip "tar -xzf - -C /path/to/backup_dir/"
```
> [!NOTE]
> Database checkpoints cover database tables and metadata. Versioned depot files reside under `./depots` (or your NAS path). Regularly back up both the checkpoints and depot directory.

#### Restoring from a Checkpoint
If disaster recovery is required:
```powershell
# Automatically restore the newest checkpoint:
docker compose exec p4d /usr/local/bin/restore.sh

# Or restore a specific checkpoint:
docker compose exec p4d ln -sf /opt/perforce/p4/home/checkpoints/perforce-server.ckp.1.gz /opt/perforce/p4/home/checkpoints/latest
docker compose exec p4d /usr/local/bin/restore.sh
```

### 2. View Server Configuration
```bash
docker compose exec p4d p4 configure show
```

### 3. Graceful Container Stop
The container traps `SIGTERM` and `SIGINT`, flushes open transactions, and executes `p4dctl stop`:
```powershell
docker compose stop
```

### 4. Upgrading Perforce (`helix-p4d`)
Upgrades are safe and predictable:
1. **Take a checkpoint first:**
   ```powershell
   docker compose exec p4d p4 admin checkpoint -z
   ```
2. **Pull the latest prebuilt image or rebuild:**
   ```powershell
   docker compose pull
   # Or rebuild from source:
   docker compose build --no-cache --pull
   ```
3. **Restart the container:**
   ```powershell
   docker compose up -d
   ```
   *Database schema upgrades (`p4d -xu`) run automatically on startup.*

### 5. User Management & Permissions
The user defined in `.env` (`P4USER`, defaults to `admin`) is granted **`super`** privileges.

#### Check Current Identity & Access
```powershell
docker compose exec p4d p4 info
docker compose exec p4d p4 protects
```

#### Create a Standard User (e.g., `alice`)
```powershell
docker compose exec p4d bash -c "p4 user -f -o alice | p4 user -f -i"
docker compose exec p4d p4 passwd alice
```

#### Edit Permissions Table (`p4 protect`)
Open the protections table in `nano`:
```powershell
docker compose exec -it p4d p4 protect
```
Example restricting an external contractor (`ext_alice`) to specific folders:
```text
write user ext_alice * //depot/projects/their_subproject/...
read  user ext_alice * //depot/projects/shared/...
```

### 6. Client Load Testing (`p4-loadtest.ps1`)
A multi-client PowerShell load-testing script is included in the repository root to measure client-side latency (p50/p95/p99), throughput, and error rates:
```powershell
# Run with defaults against localhost:1666
.\p4-loadtest.ps1

# Custom target and concurrency:
.\p4-loadtest.ps1 -Server 100.x.x.x -Port 1666 -Clients 8 -OpsPerClient 300
```

---

## Running with SSL

1. **Generate certificates:**
   ```bash
   docker compose run --rm --entrypoint /usr/local/bin/ssl.sh p4d /ssl
   ```
2. **Enable SSL in `docker-compose.yml`:**
   ```yaml
   environment:
     P4SSLDIR: /ssl
     P4SSL: ssl
     P4PORT: ssl:1666
   volumes:
     - ./ssl:/ssl
   ```
3. **Restart the container:**
   ```powershell
   docker compose up -d
   ```
   *Clients must prefix the port with `ssl:` (e.g., `ssl:localhost:1666`).*

---

## Troubleshooting

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| `Connection refused` | Server not yet ready or container stopped | Run `docker compose ps` and `docker compose logs -f` to verify startup. |
| Tailscale `Test-NetConnection` fails | Missing or incorrect serve rule | In Tailscale container, verify `tailscale serve status`. Ensure target is `tcp://helix-p4d:1666`. |
| `Partner exited unexpectedly` | SSL protocol mismatch | Ensure client address has `ssl:` prefix if and only if server has SSL enabled. |
| Tailscale node offline after months | Node key expired | In Tailscale admin console, select **Disable Key Expiry** for the node. |
| Linux/Windows script line-ending errors | File converted to CRLF | Repository includes `.gitattributes` enforcing LF. Run `git checkout-index -f -a` if needed. |

---

## Security Checklist

- [ ] Strong, unique `P4PASSWD` set in `.env` or stack environment.
- [ ] Live database on named volume `P4_P4ROOT`, avoiding host NTFS bind mounts.
- [ ] No ports published directly to the public internet. Use Tailscale (`docker-compose.tailscale.yml`) for remote access.
- [ ] Individual p4 accounts created per user; `super` restricted to admin tasks.
- [ ] Granular paths enforced via `p4 protect`.
- [ ] Automated periodic checkpoints scheduled and copied offsite.
