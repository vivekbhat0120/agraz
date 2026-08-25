import posixpath
import os
from pathlib import Path

import paramiko

root = Path(r"d:\fullstack\others\app_agraz")
creds = {}
for line in (root / ".vps_credentials").read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    creds[k.strip()] = v.strip().strip('"').strip("'")

host = creds.get("VPS_HOST", "88.222.242.192")
port = int(creds.get("VPS_PORT", "22"))
user = creds.get("VPS_USER", "root")
password = creds.get("VPS_PASSWORD")
if not password:
    raise SystemExit("VPS_PASSWORD missing")

bin_path = root / "agraz_backend" / "release" / "agraz_backend"
dist = root / "agraz_admin" / "dist"
if not bin_path.is_file():
    raise SystemExit(f"missing binary {bin_path}")
if not (dist / "index.html").is_file():
    raise SystemExit(f"missing admin dist {dist}")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
print(f"Connecting to {user}@{host}:{port} ...")
ssh.connect(
    host,
    port=port,
    username=user,
    password=password,
    timeout=30,
    allow_agent=False,
    look_for_keys=False,
)
sftp = ssh.open_sftp()


def put_dir(local, remote):
    try:
        sftp.mkdir(remote)
    except Exception:
        pass
    for name in os.listdir(local):
        lp = os.path.join(local, name)
        rp = posixpath.join(remote, name)
        if os.path.isdir(lp):
            put_dir(lp, rp)
        else:
            print(f"  upload {name} ({os.path.getsize(lp)} bytes)")
            sftp.put(lp, rp)


print("Uploading backend binary...")
sftp.put(str(bin_path), "/root/agraz_backend.new")
print("Uploading admin dist...")
ssh.exec_command("rm -rf /root/agraz_admin_dist.new")[1].channel.recv_exit_status()
put_dir(str(dist), "/root/agraz_admin_dist.new")
sftp.close()

cmd = r"""
set -euo pipefail
APP=/var/www/agraz_backend
ADMIN=/var/www/agrazllp.com/agraz_web/agraz_admin
systemctl stop agraz
cp "$APP/agraz_backend" "$APP/agraz_backend.bak"
mv /root/agraz_backend.new "$APP/agraz_backend"
chmod +x "$APP/agraz_backend"
chown www-data:www-data "$APP/agraz_backend"
mkdir -p "$APP/uploads/achievers-lobby"
chown -R www-data:www-data "$APP/uploads" || true
rm -rf "${ADMIN}.bak"
if [ -d "$ADMIN" ]; then mv "$ADMIN" "${ADMIN}.bak"; fi
mkdir -p "$ADMIN"
cp -a /root/agraz_admin_dist.new/. "$ADMIN/"
chown -R www-data:www-data "$ADMIN"
rm -rf /root/agraz_admin_dist.new
# Allow larger video uploads through nginx
for f in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/* /etc/nginx/nginx.conf; do
  [ -f "$f" ] || continue
  sed -i 's/client_max_body_size 64m/client_max_body_size 128m/g' "$f" || true
done
nginx -t && systemctl reload nginx || true
systemctl start agraz
sleep 3
systemctl --no-pager is-active agraz
curl -s -o /dev/null -w "API HTTP %{http_code}\n" https://agrazllp.com/api/ || true
curl -s -o /dev/null -w "lobby list HTTP %{http_code}\n" https://agrazllp.com/api/achievers-lobby || true
curl -s -o /dev/null -w "lobby cats HTTP %{http_code}\n" https://agrazllp.com/api/achievers-lobby/categories || true
curl -s -o /dev/null -w "lobby latest HTTP %{http_code}\n" https://agrazllp.com/api/achievers-lobby/latest || true
echo Admin: https://agrazllp.com/agraz_admin/
echo Done.
"""
print("Installing on VPS...")
_, stdout, stderr = ssh.exec_command(cmd, timeout=120)
out = stdout.read().decode("utf-8", errors="replace")
err = stderr.read().decode("utf-8", errors="replace")
code = stdout.channel.recv_exit_status()
print(out)
if err.strip():
    print(err)
ssh.close()
if code != 0:
    raise SystemExit(f"remote install failed: {code}")
print("Deploy OK")
