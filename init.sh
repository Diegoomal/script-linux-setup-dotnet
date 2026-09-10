#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Instalação do .NET SDK no Ubuntu / WSL2
# Padrão: .NET 8
#
# Uso:
#   chmod +x install-dotnet.sh
#   ./install-dotnet.sh
#
# Outra versão:
#   DOTNET_VERSION=10.0 ./install-dotnet.sh
# ============================================================

DOTNET_VERSION="${DOTNET_VERSION:-8.0}"

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '\nERRO: %s\n' "$1" >&2
  exit 1
}

if [[ ! -f /etc/os-release ]]; then
  fail "Não foi possível identificar a distribuição Linux."
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  fail "Este script foi feito para Ubuntu. Distribuição detectada: ${ID:-desconhecida}"
fi

ARCH="$(dpkg --print-architecture)"

log "Sistema detectado: Ubuntu ${VERSION_ID:-desconhecida} (${ARCH})"

if grep -qi microsoft /proc/version 2>/dev/null; then
  log "WSL detectado."
else
  log "Aviso: WSL não foi detectado, mas a instalação continuará."
fi

log "Atualizando índice de pacotes..."
sudo apt-get update

log "Instalando dependências básicas..."
sudo apt-get install -y \
  ca-certificates \
  curl \
  wget \
  gnupg \
  software-properties-common

# Ubuntu 24.04+ fornece .NET pelo próprio Ubuntu.
# O backports oficial do Ubuntu amplia as versões disponíveis.
case "${VERSION_ID:-}" in
  24.04|26.04)
    log "Configurando repositório .NET do Ubuntu..."
    sudo add-apt-repository -y ppa:dotnet/backports || true
    sudo apt-get update
    ;;

  22.04)
    # Para 22.04, adicionamos o feed oficial da Microsoft.
    log "Configurando repositório oficial da Microsoft..."
    TMP_DEB="$(mktemp --suffix=.deb)"

    curl -fsSL \
      "https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb" \
      -o "$TMP_DEB"

    sudo dpkg -i "$TMP_DEB"
    rm -f "$TMP_DEB"

    sudo apt-get update
    ;;

  *)
    log "Versão Ubuntu ${VERSION_ID:-desconhecida} não tratada explicitamente."
    log "Tentando instalar pelo repositório disponível do sistema..."
    ;;
esac

PACKAGE="dotnet-sdk-${DOTNET_VERSION}"

log "Verificando disponibilidade de ${PACKAGE}..."
if ! apt-cache show "$PACKAGE" >/dev/null 2>&1; then
  printf '\nPacote %s não encontrado nos repositórios configurados.\n' "$PACKAGE" >&2
  printf 'Versões disponíveis:\n' >&2
  apt-cache search '^dotnet-sdk-[0-9]' | sed -n '1,20p' >&2 || true
  exit 1
fi

log "Instalando ${PACKAGE}..."
sudo apt-get install -y "$PACKAGE"

log "Validando instalação..."

if ! command -v dotnet >/dev/null 2>&1; then
  fail "O pacote foi instalado, mas o comando 'dotnet' não está no PATH."
fi

echo
dotnet --info

echo
echo "SDKs instalados:"
dotnet --list-sdks

echo
echo "Instalação concluída com sucesso."
