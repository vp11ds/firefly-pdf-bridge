#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
compose_file=firefly/docker-compose.yml
users_file=firefly/authelia/users_database.yml

if [ ! -f .env ]; then
  printf '%s\n' 'Create app2/.env from .env.example and set strong local TEST secrets first.' >&2
  exit 1
fi

if [ -e "$users_file" ]; then
  printf '%s\n' "$users_file already exists; refusing to overwrite it." >&2
  exit 1
fi

printf 'Authelia username: '
IFS= read -r username
printf 'SSO email (must also be Firefly SITE_OWNER): '
IFS= read -r email

case "$username" in
  ''|*[!A-Za-z0-9_.-]*) printf '%s\n' 'Username may contain only letters, digits, dot, underscore, and hyphen.' >&2; exit 1 ;;
esac
case "$email" in
  *@*.*) ;;
  *) printf '%s\n' 'Enter a valid email address.' >&2; exit 1 ;;
esac
case "$email" in
  *[!A-Za-z0-9_.@-]*) printf '%s\n' 'Email may contain only letters, digits, @, dot, underscore, and hyphen.' >&2; exit 1 ;;
esac

printf '%s\n' 'Enter and confirm the SSO password in Authelia'
hash=$(docker compose --project-directory . -f "$compose_file" run --rm --no-deps --entrypoint authelia sso crypto hash generate argon2 | sed -n 's/^Digest: //p')
case "$hash" in
  '$argon2id$'*) ;;
  *) printf '%s\n' 'Authelia did not return an Argon2id hash; no file written.' >&2; exit 1 ;;
esac

umask 077
{
  printf 'users:\n  %s:\n' "$username"
  printf '    displayname: "%s"\n' "$username"
  printf '    email: "%s"\n' "$email"
  printf '    password: "%s"\n' "$hash"
  printf '    groups:\n      - admins\n'
} > "$users_file"
chmod 600 "$users_file"
printf 'Created %s with mode 0600. Keep the email identical to Firefly SITE_OWNER.\n' "$users_file"
