#!/bin/bash
set -euo pipefail
# Repository-specific read-only deploy keys; never personal tokens.
# Run only in trusted same-repository CI, never pull_request_target.
umask 077
credential_dir="$RUNNER_TEMP/shared-kit-credentials"
mkdir -p "$credential_dir"
cp Scripts/github_known_hosts "$credential_dir/known_hosts"
: > "$credential_dir/ssh_config"
: > "$credential_dir/gitconfig"
while read -r package secret_name; do
    credential="${!secret_name:-}"
    if [ -z "$credential" ]; then
        echo "Missing required CI secret: $secret_name" >&2
        exit 1
    fi
    printf '%s\n' "$credential" > "$credential_dir/$package"
    unset credential
    host="$(printf '%s' "$package" | tr '[:upper:]' '[:lower:]')-ci"
    cat >> "$credential_dir/ssh_config" <<CONFIG
Host $host
  HostName github.com
  User git
  IdentityFile "$credential_dir/$package"
  IdentitiesOnly yes
  BatchMode yes
  StrictHostKeyChecking yes
  UserKnownHostsFile "$credential_dir/known_hosts"
CONFIG
    git config --file "$credential_dir/gitconfig" \
        url."ssh://git@$host/Anurag-Chourasia/$package.git".insteadOf \
        "https://github.com/Anurag-Chourasia/$package.git"
done <<'PACKAGES'
DesignTokensKit DESIGNTOKENSKIT_DEPLOY_KEY
UIComponentsKit UICOMPONENTSKIT_DEPLOY_KEY
PACKAGES
printf 'GIT_CONFIG_GLOBAL=%s\n' "$credential_dir/gitconfig" >> "$GITHUB_ENV"
printf 'GIT_SSH_COMMAND=ssh -F "%s"\n' "$credential_dir/ssh_config" >> "$GITHUB_ENV"
