# 9Router Railway Deployment Guide

## Quick Deploy (Docker)

### 1. Push to GitHub
```bash
git add .
git commit -m "chore: add Railway config"
git push origin main
```

### 2. Create Railway Project
1. Go to https://railway.app
2. New Project → Deploy from GitHub repo
3. Select your 9router repo
4. Railway auto-detects Dockerfile

### 3. Set Environment Variables (Railway Dashboard → Variables)
**Required (generate strong random values):**
```
JWT_SECRET=<64-char random>
INITIAL_PASSWORD=<strong password>
API_KEY_SECRET=<64-char random>
MACHINE_ID_SALT=<32-char random>
```

**Auto-set by Railway (do NOT override):**
- PORT
- RAILWAY_GIT_COMMIT_SHA
- RAILWAY_STATIC_URL (e.g. `your-app.up.railway.app`)
- RAILWAY_ENVIRONMENT=production

**Production settings:**
```
NODE_ENV=production
HOSTNAME=0.0.0.0
DATA_DIR=/app/data
AUTH_COOKIE_SECURE=true
ENABLE_REQUEST_LOGS=false
OBSERVABILITY_ENABLED=true
```

**After first deploy - set your public URL:**
```
BASE_URL=https://your-app.up.railway.app
NEXT_PUBLIC_BASE_URL=https://your-app.up.railway.app
CLOUD_URL=https://your-app.up.railway.app
NEXT_PUBLIC_CLOUD_URL=https://your-app.up.railway.app
```

### 4. Add Persistent Volume
Railway Dashboard → Service → Volumes → Add Volume
- Mount path: `/app/data`
- This persists SQLite DB, configs, backups across deploys

### 5. Deploy
Railway builds Dockerfile → runs health check on `/api/health` → promotes on success.

---

## Files Added

| File | Purpose |
|------|---------|
| `railway.toml` | Railway build/deploy config |
| `.env.railway` | Template for env vars |

---

## Verify Locally (optional)

```bash
# Build image
docker build -t 9router .

# Run with .env.railway values
docker run -d --name 9router-test -p 20128:20128 --env-file .env.railway -v 9router-data:/app/data 9router

# Health check
curl http://localhost:20128/api/health
# {"ok":true}
```

---

## Key Points for Railway

1. **PORT**: Railway injects `PORT` env var. Dockerfile has `ENV PORT=20128` as default, but Railway's value wins at runtime. `custom-server.js` reads `process.env.PORT` via `applyDotEnvPort()`.

2. **HTTPS**: Railway terminates TLS. `AUTH_COOKIE_SECURE=true` is required so session cookies work.

3. **BASE_URL**: Must be set to your Railway URL (`https://xxx.up.railway.app`) after first deploy so OAuth/SAML redirects and update checks work.

4. **DATA_DIR**: `/app/data` in container. Mount Railway volume here for persistence.

5. **Health Check**: `/api/health` returns `{"ok":true}` with CORS `*` — works for Railway's health checks.

6. **RAILWAY_GIT_COMMIT_SHA**: Dockerfile accepts this as build arg so `APP_REVISION` gets stamped for the release banner.
