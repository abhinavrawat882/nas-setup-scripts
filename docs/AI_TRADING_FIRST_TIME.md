# AI Trading on NAS — first-time setup (detailed)

Your NAS already runs RabbitMQ, Registry, and TellegramService. AI Trading is an
extra service on the same `nas` Docker network.

**Your data root:** `NAS_ROOT=/srv/nas`  
**Dashboard:** `http://arnosatlas:5100` (or `http://100.92.27.123:5100`)

---

## What you end up with

| Piece | Where |
|-------|--------|
| Config | `/srv/nas/docker/ai-trading/config.yaml` |
| Portfolio / cache / reports | `/srv/nas/docker/ai-trading/data/` |
| Container | `ai-trading` (Flask dashboard + analysis) |
| Scheduler | `ai-trading-ofelia` — Mon–Fri **07:00** and **19:00** (`TZ`) |
| Telegram | Same RabbitMQ → Tellegram path as today |
| Report links in Telegram | `http://<TAILSCALE_IP>:5100/api/reports/report_….html` |

---

## One-time checklist

### A) On your Mac — push the image (once per code change)

```bash
cd "/Users/arno/Documents/Projects/AI Trading"
./scripts/build-push-nas.sh
```

Details: [NAS_REGISTRY_PUSH.md](../../AI%20Trading/docs/NAS_REGISTRY_PUSH.md) in the AI Trading repo  
(or sibling path if you open that repo). Shared rule: use **crane**, not `docker push`.

### B) On the NAS — create folders + seed config

```bash
cd /path/to/nas-setup-scripts   # wherever you cloned this repo on the NAS
sudo ./scripts/07-setup-ai-trading.sh
```

That script:

1. Creates `/srv/nas/docker/ai-trading/data/{portfolio,stocks_cache,reports}`
2. Writes `/srv/nas/docker/ai-trading/config.yaml` from a template
3. Fills RabbitMQ user/password + dashboard URL from your `config.env`
4. Prints the exact `sudo nano …` command for you to finish editing

Then edit:

```bash
sudo nano /srv/nas/docker/ai-trading/config.yaml
```

**Must set / verify:**

- `capital.monthly_allocation` — Groww cash / monthly budget  
- `portfolio.long_term_holds` — optional, e.g. `["ITC", "SBIN"]`  
- `alerts.rabbitmq.password` — should already match `RABBITMQ_PASS` in `config.env`  
- `alerts.enabled: true`

Optional in `config.env` (same repo on NAS):

```bash
TZ=Asia/Kolkata          # so 07:00/19:00 are IST
AI_TRADING_PORT=5100     # default
GEMINI_API_KEY=...       # optional AI review
```

### C) On the NAS — start containers

```bash
sudo ./scripts/07-setup-ai-trading.sh --deploy
# equivalent: sudo ./scripts/05-deploy-projects.sh
```

### D) In the browser (Tailscale on)

1. Open `http://arnosatlas:5100`
2. **Portfolio** → **Import Groww** (if you have an export in data) **or Add row**
3. Edit qty / avg / buy date → **Save**
4. Set cash → **Update cash**
5. **Run Analysis**
6. Check Telegram for the alert + report link

---

## Day-2 / after code changes

```bash
# Mac
./scripts/build-push-nas.sh

# NAS
sudo ./scripts/05-deploy-projects.sh
```

Config and `data/` are bind-mounted — **not wiped** on redeploy.

---

## Script reference

| Command | What it does |
|---------|----------------|
| `sudo ./scripts/07-setup-ai-trading.sh` | Create dirs + seed config; print nano instructions |
| `sudo ./scripts/07-setup-ai-trading.sh --force` | Overwrite `config.yaml` from template again |
| `sudo ./scripts/07-setup-ai-trading.sh --deploy` | Above + pull/start `ai-trading` (+ rest of projects stack) |

Compose cannot invent a missing host config file by itself in a friendly way, so this
script is the supported “first run” path. Folders are also created by
`02-prepare-dirs.sh` when you deploy projects.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `:5100` connection refused | Image not pulled / container not started — run `--deploy`; check `docker ps \| grep ai-trading` |
| Container exits / `Restarting` | Wrong arch image (need `linux/amd64`) — rebuild with `./scripts/build-push-nas.sh`; check `docker logs ai-trading` |
| `sed: unterminated s` on setup | Fixed — pull latest `07-setup-ai-trading.sh`; re-run with `--force` if config is empty/broken |
| No Telegram | `tellegram` up? `alerts.enabled`? RabbitMQ password match? |
| Report link doesn’t open | Phone on Tailscale? URL host = NAS Tailscale IP/MagicDNS |
| Wrong schedule time | Set `TZ=Asia/Kolkata` in `config.env`, redeploy |
