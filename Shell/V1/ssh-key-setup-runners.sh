#!/bin/bash
set -euo pipefail

SSH_DIR="${HOME}/.ssh"

if [[ -v "LZ_GITLAB_KEY" ]]; then
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"

  printf '%s' "${LZ_GITLAB_KEY}" > "${SSH_DIR}/id_rsa"
  chmod 600 "${SSH_DIR}/id_rsa"

  rm -f "${SSH_DIR}/known_hosts"
  ssh-keyscan d.c.co.uk >> "${SSH_DIR}/known_hosts" 2>/dev/null
  chmod 600 "${SSH_DIR}/known_hosts"
fi