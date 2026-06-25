#!/bin/bash
set -e
set -o pipefail

SSH_DIR="${HOME}/.ssh"

if [[ -v "LZ_GITLAB_KEY" ]]; then
  mkdir -p "${SSH_DIR}/"
  echo "${LZ_GITLAB_KEY}" > "${SSH_DIR}/id_rsa"  
  # Delete known hosts to avoid issues with the
  # host key changing when GitLab is updated
  if [ -f "${SSH_DIR}/known_hosts" ]; then
      rm -f "${SSH_DIR}/known_hosts"
  fi
  ssh-keyscan d.c.co.uk >> "${SSH_DIR}/known_hosts"
  chmod 600 "${SSH_DIR}/id_rsa"
  chown -R root:root "${SSH_DIR}"
fi
