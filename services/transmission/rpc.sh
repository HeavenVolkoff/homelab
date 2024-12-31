#!/usr/bin/env sh

set -eu

# Validate arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <rpc-method>" >&2
  exit 1
fi

if [ -z "$1" ] || [ "$1" != "session-stats" ] && [ "$1" != "blocklist-update" ]; then
  echo 'rpc-method must be either "session-stats" or "blocklist-update"' >&2
  exit 1
fi

# Check if exported variables were set
if [ -z "${TRANSMISSION_RPC_PORT:-}" ] || [ -z "${TRANSMISSION_RPC_USER:-}" ] || [ -z "${TRANSMISSION_RPC_PASSWORD:-}" ]; then
  echo "Unable to read rpc config" >&2
  exit 1
fi

# Build request body
_req="$(
  cat <<EOF
POST /transmission/rpc HTTP/1.1
Host: localhost:$TRANSMISSION_RPC_PORT
Authorization: Basic $(printf '%s:%s' "$TRANSMISSION_RPC_USER" "$TRANSMISSION_RPC_PASSWORD" | base64)
Content-Type: application/json
Content-Length: $(($(printf '%s' "$1" | wc -c) + 13))
X-Transmission-Session-Id: %s
Connection: close

{"method":"$1"}
EOF
)"

# Get a valid session-id
_transmission_id="$(
  # shellcheck disable=SC2059
  printf "$_req" 0 | nc localhost "$TRANSMISSION_RPC_PORT" | awk -F': ' '$1 == "X-Transmission-Session-Id" { print $2 }'
)"

# Send request
_request_status="$(
  # shellcheck disable=SC2059
  printf "$_req" "$_transmission_id" | nc localhost "$TRANSMISSION_RPC_PORT" | head -n1
)"

# Trim whitespace
_request_status="${_request_status#"${_request_status%%[![:space:]]*}"}"
_request_status="${_request_status%"${_request_status##*[![:space:]]}"}"

# Check if request was successful
[ "$_request_status" = "HTTP/1.1 200 OK" ]
