#!/bin/bash
# Select this checkout's GitHub CLI configuration, without switching global accounts.
set -euo pipefail
cd "$(dirname "$0")/.."
git_dir="$(git rev-parse --absolute-git-dir)"
umask 077
mkdir -p "$git_dir/gh-local-auth"
chmod 700 "$git_dir/gh-local-auth"
if [[ "${1:-} ${2:-}" != 'auth login' ]] && ! grep -Eq '^[[:space:]]*oauth_token: .+' "$git_dir/gh-local-auth/hosts.yml" 2>/dev/null; then
  echo 'No project-local login. Run ./script/gh-local.sh auth login --hostname github.com --git-protocol https --web' >&2
  exit 1
fi
# Prevent an inherited token/host/repository from silently overriding local selection.
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_REPO
export GH_CONFIG_DIR="$git_dir/gh-local-auth"
export GH_HOST=github.com
if [[ "${1:-} ${2:-}" == 'auth login' ]]; then
  exec gh "$@" --insecure-storage
fi
exec gh "$@"
