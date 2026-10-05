#!/usr/bin/env bash
# Generate a local-only docker/.env from docker/.env.template.
# Secrets are generated here and never printed.
set -euo pipefail

SELF_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMON_ROOT="$(dirname "$(git -C "$SELF_ROOT" rev-parse --path-format=absolute --git-common-dir)")"
export TEMPLATE="${TEMPLATE:-$SELF_ROOT/docker/.env.template}"
export ENV_OUT="${ENV_OUT:-$COMMON_ROOT/docker/.env}"
export TOKEN_FILE="${TOKEN_FILE:-$COMMON_ROOT/mapbox-key.txt}"

python3 - <<'PY'
import os, re, secrets, sys

tpl, out, tok = os.environ["TEMPLATE"], os.environ["ENV_OUT"], os.environ["TOKEN_FILE"]
if os.path.exists(out):
    sys.exit(f"refusing to overwrite existing {out}")

token = ""
if os.path.exists(tok):
    token = "".join(open(tok).read().split())
if not token:
    print(f"warning: no Mapbox token found at {tok}; VITE_MAPBOXTOKEN left empty (map will not render)", file=sys.stderr)

rnd = lambda n=12: secrets.token_hex(n)
values = {
    "NODE_ENV": "development",
    "VITE_MAPBOXTOKEN": token,
    "JWT_SECRET": rnd(), "IDNO_SALT": rnd(),
    "DASHBOARD_DEFAULT_USERNAME": "admin",
    "DASHBOARD_DEFAULT_Email": "admin@example.com",
    "DASHBOARD_DEFAULT_PASSWORD": rnd(8),
    "DB_DASHBOARD_PASSWORD": rnd(), "DB_MANAGER_PASSWORD": rnd(),
    "PGADMIN_DEFAULT_EMAIL": "pgadmin@example.com", "PGADMIN_DEFAULT_PASSWORD": rnd(8),
    "QDRANT_API_KEY": rnd(),
}

lines, touched = [], []
for line in open(tpl).read().splitlines():
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
    if m and m.group(1) in values:
        line = f"{m.group(1)}={values[m.group(1)]}"
        touched.append(m.group(1))
    lines.append(line)

missing = sorted(set(values) - set(touched))
if missing:
    sys.exit("template is missing expected keys: " + ", ".join(missing))

os.makedirs(os.path.dirname(out), exist_ok=True)
tmp = out + ".tmp"
try:
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
except FileExistsError:
    sys.exit(f"refusing to overwrite existing {out}")
try:
    with os.fdopen(fd, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.link(tmp, out)   # fails if `out` exists (even as a dangling symlink): no-clobber, atomic
    os.unlink(tmp)
except FileExistsError:
    os.unlink(tmp)
    sys.exit(f"refusing to overwrite existing {out}")
except BaseException:
    if os.path.lexists(tmp):
        os.unlink(tmp)
    raise
print(f"wrote {out} (mode 600); set: {', '.join(touched)}")
PY
