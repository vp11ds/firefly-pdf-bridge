#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
compose_file=firefly/docker-compose.yml
users_file=firefly/authelia/users_database.yml
credentials_file=firefly/authelia/sample-credentials.txt

if [ ! -f .env ]; then
  printf '%s\n' 'Create app2/.env from .env.example and set strong local TEST secrets first.' >&2
  exit 1
fi

if [ -e "$users_file" ]; then
  printf '%s\n' "$users_file already exists; refusing to overwrite it." >&2
  exit 1
fi

username=testuser
displayname='Sample Test User'
email=$(sed -n 's/^SSO_EMAIL=//p' .env | tail -n 1)
case "$email" in
  *@*.*) ;;
  *) printf '%s\n' 'Set a valid SSO_EMAIL in .env before creating the sample SSO user.' >&2; exit 1 ;;
esac
case "$email" in
  *[!A-Za-z0-9_.@-]*) printf '%s\n' 'SSO_EMAIL may contain only letters, digits, @, dot, underscore, and hyphen.' >&2; exit 1 ;;
esac

generated=$(docker compose --project-directory . -f "$compose_file" run --rm --no-deps --entrypoint authelia sso crypto hash generate argon2 --random)
password=$(printf '%s\n' "$generated" | sed -n 's/^Random Password: //p')
hash=$(printf '%s\n' "$generated" | sed -n 's/^Digest: //p')
case "$password" in
  ''|*[!A-Za-z0-9]*) printf '%s\n' 'Authelia did not return a valid random password; no files written.' >&2; exit 1 ;;
esac
case "$hash" in
  '$argon2id$'*) ;;
  *) printf '%s\n' 'Authelia did not return an Argon2id hash; no file written.' >&2; exit 1 ;;
esac

umask 077
{
  printf 'users:\n  %s:\n' "$username"
  printf '    displayname: "%s"\n' "$displayname"
  printf '    email: "%s"\n' "$email"
  printf '    password: "%s"\n' "$hash"
  printf '    groups:\n      - admins\n'
} > "$users_file"
{
  printf 'Username: %s\n' "$username"
  printf 'Email: %s\n' "$email"
  printf 'Password: %s\n' "$password"
} > "$credentials_file"
chmod 600 "$users_file"
chmod 600 "$credentials_file"
printf 'Created the sample SSO account and local credentials file: %s (mode 0600).\n' "$credentials_file"
