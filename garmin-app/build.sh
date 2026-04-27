#!/usr/bin/env bash
# unforzed — Garmin Connect IQ build script
# Usage:
#   ./build.sh                        # build para fr265 (simulador)
#   ./build.sh -d fenix7              # otro device
#   ./build.sh -d all                 # todos los targets del manifest
#   ./build.sh -d fr265 --release     # .iq para cargar en el reloj
#   ./build.sh -d fr265 --run         # build + lanzar simulador
#   ./build.sh --keygen               # genera developer key (solo primera vez)
#   ./build.sh --devices              # lista los targets soportados

set -euo pipefail

# ── Colores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${CYAN}▸${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

# ── Targets soportados ────────────────────────────────────────────────────────
ALL_DEVICES=(
  fr255 fr255s fr255m fr255sm
  fr265 fr265s
  fenix7 fenix7s fenix7x fenix7pro fenix7xpro
  venu2 venu2s venu3 venu3s
)

# ── Defaults ──────────────────────────────────────────────────────────────────
DEVICE="fr265"
RELEASE=false
RUN_SIM=false
KEYGEN=false
LIST_DEVICES=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/build"
KEY_PEM="${SCRIPT_DIR}/developer_key.pem"
KEY_DER="${SCRIPT_DIR}/developer_key.der"
MANIFEST="${SCRIPT_DIR}/manifest.xml"
JUNGLE="${SCRIPT_DIR}/monkey.jungle"

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)   DEVICE="${2:-fr265}"; shift 2 ;;
    --release)     RELEASE=true; shift ;;
    --run)         RUN_SIM=true; shift ;;
    --keygen)      KEYGEN=true; shift ;;
    --devices)     LIST_DEVICES=true; shift ;;
    -h|--help)
      echo -e "${BOLD}unforzed build script${NC}"
      echo ""
      echo "  ./build.sh                      build simulador (fr265)"
      echo "  ./build.sh -d fenix7            otro device"
      echo "  ./build.sh -d all               todos los targets"
      echo "  ./build.sh -d fr265 --release   .iq para cargar al reloj"
      echo "  ./build.sh -d fr265 --run       build + lanzar simulador"
      echo "  ./build.sh --keygen             genera developer key"
      echo "  ./build.sh --devices            lista targets soportados"
      exit 0
      ;;
    *) error "Opción desconocida: $1" ;;
  esac
done

# ── Listar devices ────────────────────────────────────────────────────────────
if $LIST_DEVICES; then
  echo -e "${BOLD}Targets soportados:${NC}"
  for d in "${ALL_DEVICES[@]}"; do echo "  $d"; done
  exit 0
fi

# ── Localizar SDK ─────────────────────────────────────────────────────────────
find_sdk() {
  # 1. Variable de entorno explícita
  if [[ -n "${CIQ_HOME:-}" && -x "${CIQ_HOME}/bin/monkeyc" ]]; then
    echo "${CIQ_HOME}"; return
  fi

  # 2. En el PATH
  if command -v monkeyc &>/dev/null; then
    echo "$(dirname "$(dirname "$(command -v monkeyc)")")"; return
  fi

  # 3. Ubicaciones típicas en macOS (SDK Manager instala aquí)
  local sdk_base="${HOME}/Library/Application Support/Garmin/ConnectIQ/Sdks"
  if [[ -d "${sdk_base}" ]]; then
    # El directorio más reciente
    local latest
    latest=$(ls -t "${sdk_base}" 2>/dev/null | head -1)
    if [[ -n "${latest}" && -x "${sdk_base}/${latest}/bin/monkeyc" ]]; then
      echo "${sdk_base}/${latest}"; return
    fi
  fi

  # 4. VS Code extension path
  local vscode_ext="${HOME}/.vscode/extensions"
  if [[ -d "${vscode_ext}" ]]; then
    local ext_path
    ext_path=$(find "${vscode_ext}" -name "monkeyc" -type f 2>/dev/null | head -1)
    if [[ -n "${ext_path}" ]]; then
      echo "$(dirname "$(dirname "${ext_path}")")"; return
    fi
  fi

  echo ""
}

SDK_HOME="$(find_sdk)"

if [[ -z "${SDK_HOME}" ]]; then
  echo ""
  echo -e "${RED}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  Connect IQ SDK no encontrado                         ║${NC}"
  echo -e "${RED}╚═══════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}Pasos para instalarlo:${NC}"
  echo ""
  echo "  1. Descarga el SDK Manager:"
  echo "     https://developer.garmin.com/connect-iq/sdk/"
  echo ""
  echo "  2. Instala el SDK (recomendado: versión ≥ 7.x)"
  echo "     El SDK Manager lo deja en:"
  echo "     ~/Library/Application Support/Garmin/ConnectIQ/Sdks/"
  echo ""
  echo "  3. Opcionalmente, añade al PATH en ~/.zshrc:"
  echo "     export CIQ_HOME=\"\$HOME/Library/Application Support/"
  echo "       Garmin/ConnectIQ/Sdks/<versión>\""
  echo "     export PATH=\"\$CIQ_HOME/bin:\$PATH\""
  echo ""
  echo "  4. Vuelve a ejecutar este script."
  echo ""
  exit 1
fi

MONKEYC="${SDK_HOME}/bin/monkeyc"
SIMULATOR="${SDK_HOME}/bin/connectiq"
MONKEYDO="${SDK_HOME}/bin/monkeydo"

ok "SDK encontrado en: ${SDK_HOME}"
info "monkeyc: $("${MONKEYC}" --version 2>&1 | head -1)"

# ── Generar developer key ─────────────────────────────────────────────────────
generate_key() {
  info "Generando developer key (solo necesario una vez)..."
  if ! command -v openssl &>/dev/null; then
    error "openssl no encontrado. Instálalo con: brew install openssl"
  fi
  openssl genrsa -out "${KEY_PEM}" 4096 2>/dev/null
  openssl pkcs8 -topk8 -inform PEM -outform DER \
    -in "${KEY_PEM}" -out "${KEY_DER}" -nocrypt
  chmod 600 "${KEY_PEM}" "${KEY_DER}"
  ok "Keys generadas:"
  echo "   ${KEY_PEM}  ← guarda esto en privado, no lo subas a git"
  echo "   ${KEY_DER}  ← este usa monkeyc"
}

if $KEYGEN; then
  if [[ -f "${KEY_DER}" ]]; then
    warn "developer_key.der ya existe. Usa --keygen solo si quieres regenerar."
    read -r -p "¿Regenerar? (s/N): " confirm
    [[ "${confirm,,}" == "s" ]] || { info "Cancelado."; exit 0; }
  fi
  generate_key
  exit 0
fi

# Verificar que existe la key (y crearla si no)
if [[ ! -f "${KEY_DER}" ]]; then
  warn "developer_key.der no encontrado."
  read -r -p "¿Generar ahora? (S/n): " confirm
  [[ "${confirm,,}" == "n" ]] && error "Se necesita developer_key.der para compilar."
  generate_key
fi

# ── Preparar output dir ───────────────────────────────────────────────────────
mkdir -p "${OUT_DIR}"

# ── Función de build ──────────────────────────────────────────────────────────
build_device() {
  local dev="$1"
  local ext; $RELEASE && ext="iq" || ext="prg"
  local out="${OUT_DIR}/unforzed_${dev}.${ext}"

  echo ""
  info "Building ${BOLD}${dev}${NC} → $(basename "${out}")"

  local flags=(-f "${JUNGLE}" -o "${out}" -d "${dev}" -y "${KEY_DER}")
  $RELEASE && flags+=(--release) || flags+=()

  if "${MONKEYC}" "${flags[@]}" 2>&1; then
    ok "${dev}: ${out}"
    echo "${out}"   # retorna la ruta para --run
  else
    echo -e "${RED}✗ Build fallido para ${dev}${NC}" >&2
    return 1
  fi
}

# ── Build ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}unforzed — Garmin build${NC}"
echo -e "Mode: $(${RELEASE} && echo 'RELEASE (.iq)' || echo 'SIMULATOR (.prg)')"
echo "────────────────────────────────────"

BUILT_PRG=""

if [[ "${DEVICE}" == "all" ]]; then
  if $RELEASE; then
    # Release: build todos
    ok_count=0; fail_count=0
    for dev in "${ALL_DEVICES[@]}"; do
      build_device "${dev}" && ((ok_count++)) || ((fail_count++))
    done
    echo ""
    echo -e "${BOLD}Resultado: ${GREEN}${ok_count} OK${NC}  ${RED}${fail_count} errores${NC}"
    [[ $fail_count -gt 0 ]] && exit 1
  else
    warn "--d all tiene sentido con --release. En modo sim usa un device específico."
    exit 1
  fi
else
  # Verificar que el device es válido
  valid=false
  for d in "${ALL_DEVICES[@]}"; do [[ "$d" == "${DEVICE}" ]] && valid=true; done
  $valid || error "Device '${DEVICE}' no reconocido. Usa --devices para ver la lista."

  BUILT_PRG="$(build_device "${DEVICE}")"
fi

# ── Lanzar simulador ──────────────────────────────────────────────────────────
if $RUN_SIM; then
  if $RELEASE; then
    error "--run no es compatible con --release (el simulador necesita .prg)"
  fi
  if [[ -z "${BUILT_PRG}" ]]; then
    error "No se generó ningún .prg para lanzar."
  fi

  echo ""
  info "Lanzando simulador para ${DEVICE}..."

  # Arrancar connectiq en background si no está corriendo
  if ! pgrep -f "connectiq" &>/dev/null; then
    info "Iniciando Connect IQ Simulator..."
    "${SIMULATOR}" &
    sleep 2
  fi

  "${MONKEYDO}" "${BUILT_PRG}" "${DEVICE}"
fi

echo ""
ok "Done."
