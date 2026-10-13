# Firefly PDF Bridge

This repository is being built in phases. Phase 0 provides one local HTTPS entrypoint with Authelia SSO in front of Firefly III, the official importer, and a Phase 1 bridge placeholder. PDF parsing and publishing are not implemented yet.

## TEST Stack

Requirements: Docker Engine and Docker Compose. No host Python, pip, or apt packages are needed.

1. From this directory, run `./setup-test-env.sh`. It prompts for the SSO email, generates unique TEST secrets inside a pinned Docker image, and writes `.env` with mode `0600`. The `.env` file is ignored by Git.
2. Create the Authelia password database by running `./firefly/setup-sso-user.sh`. Authelia prompts for the password twice in the terminal; the script writes only its Argon2 hash to ignored `firefly/authelia/users_database.yml` with mode `0600`. Use the same email as the `.env` `SSO_EMAIL` value.
3. Add this mapping to the host's `/etc/hosts`:

   ```text
   127.0.0.1 firefly.test importer.firefly.test bridge.firefly.test auth.firefly.test
   ```

4. Start the complete TEST stack with one command:

   ```sh
   docker compose --project-directory . -f firefly/docker-compose.yml up -d
   ```

5. Caddy uses its local internal certificate authority. After the stack starts, export its root certificate with `docker cp firefly-test-proxy:/data/caddy/pki/authorities/local/root.crt ./firefly/root.crt`, then import `firefly/root.crt` into the test browser/host trust store before opening the URLs.
6. Open `https://firefly.test:8080`. Authelia requires password and TOTP enrollment. The first visit to the fresh Firefly instance uses its local registration page, still protected by Authelia. Register the exact `SSO_EMAIL` address. Firefly remote-header auth remains disabled during this bootstrap.
7. In Firefly, create a Personal Access Token. Put it in the local `.env` as `FIREFLY_III_ACCESS_TOKEN`. Change `AUTHENTICATION_GUARD=web` to `AUTHENTICATION_GUARD=remote_user_guard`, then apply the settings with `docker compose --project-directory . -f firefly/docker-compose.yml up -d`.
8. Verify the shared session at `https://importer.firefly.test:8080` and `https://bridge.firefly.test:8080`. The importer uses the PAT and must not ask for OAuth credentials; the bridge page is only a Phase 1 placeholder.

Only `127.0.0.1:8080` is published by this Compose project. The Firefly, importer, SSO, and database containers publish no host ports. App services and database share only Docker's internal backend network; MariaDB is not host-accessible.

The default remote-user guard trusts the proxy identity header without checking it. Keep Firefly inaccessible except through Caddy, and preserve the Caddy `request_header` stripping and Authelia `forward_auth` configuration. The Firefly account email, Authelia email, and `.env` `SSO_EMAIL` must match.

Stop services without deleting their volumes:

```sh
docker compose --project-directory . -f firefly/docker-compose.yml down
```

No real statements belong in this stack. The Phase 4 REAL stack must use separate databases, volumes, hostnames, and credentials and must not be created before Phase 3 passes.
