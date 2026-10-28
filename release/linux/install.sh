#!/usr/bin/env bash
# ==============================================================================
# Script de Instalação do Stream Deck Server no Linux Mint / Ubuntu
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/streamdeck-server_1.0.0_all.deb" ]; then
    DEB_PACKAGE="$SCRIPT_DIR/streamdeck-server_1.0.0_all.deb"
elif [ -f "$SCRIPT_DIR/linux/streamdeck-server_1.0.0_all.deb" ]; then
    DEB_PACKAGE="$SCRIPT_DIR/linux/streamdeck-server_1.0.0_all.deb"
else
    DEB_PACKAGE=""
fi

echo "========================================================"
echo "    Instalador do Stream Deck Server para Linux Mint    "
echo "========================================================"

# Verifica se o apt está disponível
if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERRO: Este instalador é destinado a sistemas baseados em Debian/Ubuntu/Mint com apt."
    exit 1
fi

echo "[1/3] Instalando dependências do sistema e o pacote .deb..."
if [ -n "$DEB_PACKAGE" ] && [ -f "$DEB_PACKAGE" ]; then
    sudo apt-get update -qq
    sudo apt-get install -y "$DEB_PACKAGE"
else
    echo "Pacote .deb não encontrado localmente. Instalando dependências manuais..."
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-tk python3-pil python3-pil.imagetk libxtst6 x11-xserver-utils
fi

echo "[2/3] Atualizando atalhos e ícones do ambiente gráfico..."
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

echo "[3/3] Concluído com sucesso!"
echo "--------------------------------------------------------"
echo "O Stream Deck Server já está instalado e disponível:"
echo "1. No Menu Iniciar do Linux Mint (procure por 'Stream Deck Host')"
echo "2. Pelo terminal executando o comando: streamdeck-server"
echo "--------------------------------------------------------"

