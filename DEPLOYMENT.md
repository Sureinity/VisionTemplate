# VisionTemplate Deployment

VisionTemplate deploys as a Blue-Green Docker app behind Nginx: Postgres runs on the external `vision_network`, while app containers alternate between `vision_app_green` on host port `3000` and `vision_app_blue` on host port `3001`; Nginx proxies `vson.ghlensui.xyz` to the active port through `/etc/nginx/conf.d/vision_upstream.conf`.

## Files

- `docker-compose.yml` starts only `vision_postgres` (`postgres:16-alpine`) on `vision_network`.
- `deploy.sh` fast-forwards the VPS checkout to `origin/main`, builds the app image, starts the standby color, health-checks it on `GET /api/ping` (liveness + Postgres reachability — 503 if the DB is down) **and** the rendered root route `/` (catches a broken SSR render), swaps Nginx, removes the old color, then prunes dangling images.
- `backup.sh` writes daily `pg_dump` backups to `/var/backups/postgres` and removes `.sql.gz` files older than 7 days.
- `nginx/vision.conf` is the Nginx vhost for `vson.ghlensui.xyz`.
- `.github/workflows/deploy.yml` runs `deploy.sh` over SSH after pushes to `main`.
- `.env.deploy.example` documents the VPS-only `.env` file.

## First-time VPS bring-up

Prerequisites already exist on the Ubuntu 22.04 VPS: Docker, Docker Compose plugin, Nginx, Certbot, and the external Docker network `vision_network`.

1. Ensure the repository is checked out at `/var/www/VisionTemplate`.
2. Copy `.env.deploy.example` to `/var/www/VisionTemplate/.env` on the VPS and replace `CHANGE_ME_STRONG_PASSWORD` with a strong real value.
3. Start Postgres:

   ```sh
   cd /var/www/VisionTemplate
   docker compose up -d postgres
   ```

4. Seeding is automatic on first init. `docker-compose.yml` mounts `db/setup.sql`
   into the container's `/docker-entrypoint-initdb.d/`, which Postgres runs once
   when the `pgdata` volume is first created — so step 3 already seeds a fresh
   host. Confirm the rows landed:

   ```sh
   docker exec -i vision_postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT count(*) FROM notes;"
   ```

   Only if the volume already existed *before* this mount was added (Postgres
   skips the init dir on a non-empty volume) seed manually:

   ```sh
   docker exec -i vision_postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < db/setup.sql
   ```

   Run that from a shell where `POSTGRES_USER` and `POSTGRES_DB` match `/var/www/VisionTemplate/.env`, or source the env file first.

5. Install the Nginx vhost and create the initial upstream file:

   ```sh
   cp /var/www/VisionTemplate/nginx/vision.conf /etc/nginx/conf.d/vision.conf
   printf 'upstream vision_backend { server 127.0.0.1:3000; }\n' > /etc/nginx/conf.d/vision_upstream.conf
   nginx -t
   nginx -s reload
   ```

6. Run the first app deploy:

   ```sh
   bash /var/www/VisionTemplate/deploy.sh
   ```

## First-time TLS bootstrap

`nginx/vision.conf` is a **TLS vhost**: it has a port-80 → 443 redirect and a 443
server block that references `/etc/letsencrypt/live/vson.ghlensui.xyz/`. Because it
references cert files, it cannot be loaded before the certificate exists — so
`deploy.sh` installs it only when the cert is present (it skips the vhost with a
warning otherwise). On a brand-new host, obtain the certificate first, then let
`deploy.sh` install the vhost:

1. Point DNS: A record `vson.ghlensui.xyz` → the VPS IP. Confirm with
   `dig +short vson.ghlensui.xyz`.
2. Obtain the certificate using the standalone/webroot challenge (do **not** rely on
   `--nginx` here — there is no TLS vhost to edit yet, and the app's port-80 block is
   a pure redirect):

   ```sh
   # nginx must be free on :80 for the standalone challenge, or use --webroot
   certbot certonly --standalone -d vson.ghlensui.xyz --agree-tos -m <email>
   ```

   This also drops `/etc/letsencrypt/options-ssl-nginx.conf` and
   `/etc/letsencrypt/ssl-dhparams.pem`, which the vhost includes.
3. Re-run `deploy.sh`. With the cert now present, it installs `nginx/vision.conf`,
   runs `nginx -t`, and reloads — serving HTTPS.

Renewal is handled by certbot's systemd timer; verify with
`certbot renew --dry-run`. The repository does not include fabricated certificate
paths — only references to the standard Let's Encrypt live paths.

## GitHub Actions secrets

Configure these repository secrets before relying on `.github/workflows/deploy.yml`:

- `VPS_HOST` — set to the VPS host/IP value, for example the operator-provided `VPS_HOST_IP`.
- `VPS_USER` — SSH user that can run `/var/www/VisionTemplate/deploy.sh` and access Docker/Nginx as configured.
- `SSH_PRIVATE_KEY` — private key for that SSH user.

No secrets belong in Git-tracked files.

## Backups

`backup.sh` reads `/var/www/VisionTemplate/.env`, dumps `vision_postgres` with `pg_dump`, writes a timestamped `.sql.gz` under `/var/backups/postgres`, and deletes backups older than 7 days. Install the daily cron shown at the bottom of `backup.sh` if desired.

## Rollback behavior

Rollback is proven by `deploy.sh` control flow:

- If `docker build` fails, the script exits before removing the active container or touching `/etc/nginx/conf.d/vision_upstream.conf`.
- If the standby container does not return HTTP `200` from **both** `http://127.0.0.1:<standby-port>/api/ping` (liveness + DB probe) and the rendered root route `/` (catches a broken SSR render that `/api/ping` alone would miss), the script removes only that failed standby container and leaves the active container and Nginx upstream unchanged.
- Nginx is rewritten only after the standby health check passes; the old container is removed only after `nginx -t` and `nginx -s reload` both succeed.
