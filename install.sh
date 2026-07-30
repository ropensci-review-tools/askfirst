#!/usr/bin/env bash
# install.sh — one-line bootstrap for askfirst's agent hooks installer.
#
# Fetches agent-hooks/install-agent-hooks.sh from GitHub and runs it against
# the caller's current directory. Not a copy of the installer logic — see
# agent-hooks/install-agent-hooks.sh for the canonical implementation.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.sh | bash -s -- --tool claude
#   curl -fsSL https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.sh | bash -s -- --overwrite

set -euo pipefail

INSTALLER_URL="https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/agent-hooks/install-agent-hooks.sh"

curl -fsSL "$INSTALLER_URL" | bash -s -- "$@"
