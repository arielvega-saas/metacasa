#!/usr/bin/env bash
#
# Healthcheck continuo de Home Finance.
#
# Por qué existe: el 2026-07-28 se descubrió A MANO que `usehomefinance.com` llevaba días devolviendo
# HTTP 402 (`DEPLOYMENT_DISABLED`) porque Vercel había suspendido el team por facturación. La app iOS
# publicada mandaba usuarios a una página muerta y nadie se enteró. Es la lección
# `leccion-servicios-selfhosted-supervision` del harness: un servicio sin healthcheck se cae en silencio.
#
# A diferencia de release-preflight.sh (que corre una vez, antes de publicar), este script está pensado
# para correr solo cada hora y AVISAR. Ver "Instalación" abajo.
#
# Uso:
#   ./scripts/healthcheck.sh            # chequea y notifica si algo falla
#   ./scripts/healthcheck.sh --quiet    # sin salida si todo está OK (para cron/launchd)
#   ./scripts/healthcheck.sh --no-notify
#
# Salida: 0 si todo OK, 1 si algo crítico falló.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$ROOT_DIR/.healthcheck.log"
QUIET=0
NOTIFY=1

for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --no-notify) NOTIFY=0 ;;
    *) printf 'Argumento desconocido: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

FAILURES=()

say() { [[ "$QUIET" -eq 1 ]] || printf '%s\n' "$1"; }

http_status() {
  curl --silent --show-error --location --output /dev/null \
    --write-out '%{http_code}' --max-time 20 "$1" 2>/dev/null || printf '000'
}

# $1 = etiqueta legible, $2 = URL, $3... = códigos HTTP aceptables
check_url() {
  local label="$1" url="$2"; shift 2
  local status; status="$(http_status "$url")"
  local ok=0 code
  for code in "$@"; do
    [[ "$status" == "$code" ]] && ok=1
  done
  if [[ "$ok" -eq 1 ]]; then
    say "OK    $label ($status)"
  else
    say "FALLA $label — HTTP $status — $url"
    FAILURES+=("$label devolvió HTTP $status")
  fi
}

say "Home Finance healthcheck — $(date '+%Y-%m-%d %H:%M:%S')"

# --- Web pública -------------------------------------------------------------
# Cuando la web vuelva a estar arriba (Netlify), esto tiene que dar 200.
check_url "Web usehomefinance.com" "https://usehomefinance.com" 200
check_url "Web www.usehomefinance.com" "https://www.usehomefinance.com" 200

# --- Páginas legales (App Store las exige vivas) -----------------------------
check_url "Legal: privacy" "https://metacasa-app-cf592.web.app/privacy.html" 200
check_url "Legal: terms" "https://metacasa-app-cf592.web.app/terms.html" 200
check_url "Legal: account deletion" "https://metacasa-app-cf592.web.app/account-deletion.html" 200

# --- Backend -----------------------------------------------------------------
# La anon key es pública por diseño (la seguridad real es RLS), pero igual la leemos del .env
# en vez de hardcodearla, para que rotarla no rompa el chequeo.
ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  SUPABASE_URL="$(sed -n 's/^VITE_SUPABASE_URL=//p' "$ENV_FILE" | tr -d '\r')"
  SUPABASE_KEY="$(sed -n 's/^VITE_SUPABASE_ANON_KEY=//p' "$ENV_FILE" | tr -d '\r')"
  if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_KEY" ]]; then
    AUTH_STATUS="$(
      curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
        --max-time 20 -H "apikey: $SUPABASE_KEY" "$SUPABASE_URL/auth/v1/health" 2>/dev/null || printf '000'
    )"
    if [[ "$AUTH_STATUS" == "200" ]]; then
      say "OK    Supabase Auth ($AUTH_STATUS)"
    else
      say "FALLA Supabase Auth — HTTP $AUTH_STATUS"
      FAILURES+=("Supabase Auth devolvió HTTP $AUTH_STATUS")
    fi
  else
    say "FALLA .env sin configuración de Supabase"
    FAILURES+=(".env sin VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY")
  fi
else
  say "AVISO .env ausente — no se chequeó Supabase"
fi

# --- Resultado ---------------------------------------------------------------
STAMP="$(date '+%Y-%m-%d %H:%M:%S')"
if [[ "${#FAILURES[@]}" -eq 0 ]]; then
  printf '%s OK\n' "$STAMP" >> "$LOG_FILE"
  say ""
  say "Todo OK."
  exit 0
fi

SUMMARY="$(printf '%s; ' "${FAILURES[@]}")"
printf '%s FALLA %s\n' "$STAMP" "$SUMMARY" >> "$LOG_FILE"

# Notificación nativa de macOS. Se escapan las comillas para que un mensaje con " no rompa el osascript.
if [[ "$NOTIFY" -eq 1 ]] && command -v osascript >/dev/null 2>&1; then
  SAFE="${SUMMARY//\\/\\\\}"
  SAFE="${SAFE//\"/\\\"}"
  osascript -e "display notification \"$SAFE\" with title \"Home Finance CAÍDO\" sound name \"Basso\"" \
    >/dev/null 2>&1 || true
fi

# Sin --quiet ya se imprimió el detalle arriba; con --quiet imprimimos sólo el resumen a stderr
# para que launchd lo capture.
[[ "$QUIET" -eq 1 ]] && printf 'Home Finance healthcheck FALLA: %s\n' "$SUMMARY" >&2

exit 1

# -----------------------------------------------------------------------------
# Instalación (correr cada hora, con aviso en pantalla):
#
#   cp scripts/com.metacasa.healthcheck.plist ~/Library/LaunchAgents/
#   launchctl load ~/Library/LaunchAgents/com.metacasa.healthcheck.plist
#
# Para sacarlo:
#   launchctl unload ~/Library/LaunchAgents/com.metacasa.healthcheck.plist
#
# Historial: .healthcheck.log (gitignoreado).
# -----------------------------------------------------------------------------
