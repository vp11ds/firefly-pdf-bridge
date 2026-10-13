# Firefly PDF Bridge

This repository currently contains Phase 0 of a local Firefly III PDF-import workflow. The custom PDF-to-importer bridge is not implemented yet.

## TEST stack

Requirements: Docker Engine and the Docker Compose plugin. No host Python or package installation is needed.

1. Copy `.env.example` to `.env` and replace each placeholder with a test-only value. Keep `.env` private; it is excluded from Git.
2. Start the stack:

   ```sh
   docker compose -f firefly/docker-compose.yml up -d
   ```

3. Open Firefly III at http://localhost:8080. On a fresh database, create the first account using the registration page.
4. Open the data importer at http://localhost:8081. Its initial route requests a Firefly access token.

The web ports bind to `127.0.0.1` only. The database is not published to the host. Compose uses named volumes for database and upload state.

Stop the services without deleting their data:

```sh
docker compose -f firefly/docker-compose.yml down
```

Do not use this TEST stack for real statements. The `.env.example` values are placeholders, not production credentials. Real-stack isolation and the PDF bridge are future phases.
