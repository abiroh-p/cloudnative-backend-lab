# nginx/ — Stage 3: Networking layer

Nginx reverse proxy in front of two backend replicas — TLS termination,
rate limiting, and load balancing.

## One-time setup: generate a local TLS certificate

```bash
cd nginx
chmod +x generate-certs.sh
./generate-certs.sh
```

This creates `nginx/certs/localhost.{crt,key}` — gitignored, regenerate
any time. Requires `openssl` (already present in most devcontainers;
`sudo apt-get install openssl` if not).

## Running the full stack

```bash
cd ../app
docker compose up --build
```

This now starts, in order: `db` → `migrate` (runs once, exits) → `app1` +
`app2` (wait for migrate to succeed) → `nginx` (waits for both app
replicas). Watch the startup logs — `migrate` should run and exit cleanly
BEFORE either app replica starts.

## Try it

```bash
# HTTP redirects to HTTPS
curl -v http://localhost/items

# HTTPS works (-k needed: self-signed cert isn't trusted by curl/browsers by default)
curl -k https://localhost/items

curl -k -X POST https://localhost/items \
  -H "Content-Type: application/json" \
  -d '{"name": "via nginx"}'
```

## Prove load balancing is real, not just configured

Watch which replica handles each request:

```bash
docker compose logs -f app1 app2
```

In another terminal, fire several requests:

```bash
for i in $(seq 1 6); do curl -sk https://localhost/items > /dev/null; done
```

You should see `request_handled` log lines alternating between `app1` and
`app2` — round-robin in action.

## Prove failover works

```bash
docker compose stop app1
curl -k https://localhost/items   # should still succeed — served by app2
docker compose start app1
```

This is the real test of why running multiple stateless replicas matters:
one instance can go down (crash, restart, deploy) without the service as a
whole going down.

## What's deliberately simplified right now

- **Self-signed TLS** — see `docs/adr/0009-nginx-upstream-and-tls-choices.md`.
  Fine for localhost, not how a real deployment should look.
- **Explicit 2-replica upstream list** — doesn't scale elastically; see the
  same ADR. Kubernetes Services replace this in Stage 4.
- **Rate limit values (10r/s, burst 20)** are reasonable-looking defaults,
  not tuned against real traffic — a real deployment would set these based
  on actual observed load.
