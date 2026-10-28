#!/usr/bin/env bash
# ==============================================================================
# Script de Instalação do Stream Deck Server no Linux Mint / Ubuntu
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/linux/install.sh" ]; then
    exec bash "$SCRIPT_DIR/linux/install.sh" "$@"
elif [ -f "$SCRIPT_DIR/streamdeck-server_1.0.0_all.deb" ]; then
    DEB_PACKAGE="$SCRIPT_DIR/streamdeck-server_1.0.0_all.deb"
    sudo apt-get update -qq
    sudo apt-get install -y "$DEB_PACKAGE"
else
    echo "ERRO: Instalador não encontrado."
    exit 1
fi
