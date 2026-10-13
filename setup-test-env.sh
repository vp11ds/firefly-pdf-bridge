#!/bin/sh
set -eu

cd "$(dirname "$0")"

if [ -e .env ]; then
  printf '%s\n' '.env already exists; refusing to overwrite local settings.' >&2
  exit 1
fi

printf 'SSO/Firefly account email: '
IFS= read -r sso_email
case "$sso_email" in
  *@*.*) ;;
  *) printf '%s\n' 'Enter a valid email address.' >&2; exit 1 ;;
esac

caddy_image='caddy@sha256:c3d7ee5d2b11f9dc54f947f68a734c84e9c9666c92c88a7f30b9cba5da182adb'
random_hex() {
  docker run --rm --entrypoint /bin/sh "$caddy_image" -c 'head -c 48 /dev/urandom | od -An -tx1 | tr -d " \n"'
}
random_base64_key() {
  docker run --rm --entrypoint /bin/sh "$caddy_image" -c 'head -c 32 /dev/urandom | base64 | tr -d "\n"'
}

umask 077
{
  printf 'DB_PASSWORD=%s\n' "$(random_hex)"
  printf 'DB_ROOT_PASSWORD=%s\n' "$(random_hex)"
  printf 'APP_KEY=base64:%s\n' "$(random_base64_key)"
  printf 'SSO_EMAIL=%s\n' "$sso_email"
  printf 'AUTHELIA_SESSION_SECRET=%s\n' "$(random_hex)"
  printf 'AUTHELIA_STORAGE_ENCRYPTION_KEY=%s\n' "$(random_hex)"
  printf 'AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET=%s\n' "$(random_hex)"
  printf 'AUTHENTICATION_GUARD=web\n'
  printf 'FIREFLY_III_ACCESS_TOKEN=\n'
} > .env
chmod 600 .env
printf '%s\n' 'Created app2/.env with generated TEST-only secrets (mode 0600). Values were not printed.'