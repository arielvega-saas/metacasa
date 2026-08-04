#!/usr/bin/env bash
# Compara los archivos de `supabase/migrations/` contra el ledger de producción.
#
# Por qué existe: el drift entre repo y prod ya pasó dos veces en este proyecto, y las dos
# fueron silenciosas. La forma típica es aplicar algo por dashboard o por API —que asigna su
# propio timestamp— y no versionar el archivo. El resultado es que el repo deja de describir la
# base: un `db reset` produce un schema distinto al real, y razonar sobre "qué hay en prod"
# leyendo el repo da respuestas falsas.
#
# El caso más caro que encontramos: `revoke_definer_functions_from_public`, que REVOCA permisos,
# estaba aplicada sólo en prod. Reconstruir desde el repo habría dado una base más permisiva —
# el tipo de diferencia que nadie nota hasta que importa.
#
# Uso:
#   SUPABASE_DB_URL='postgresql://...' ./scripts/check-migration-drift.sh
#
# Sale 1 si hay drift, y dice de qué lado está.

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "Falta SUPABASE_DB_URL (la connection string de Postgres del proyecto)." >&2
  echo "No se hardcodea acá a propósito: lleva credenciales." >&2
  exit 2
fi

repo=$(ls supabase/migrations/*.sql 2>/dev/null | xargs -n1 basename | sed 's/_.*//' | sort -u)
prod=$(psql "$SUPABASE_DB_URL" -At -c \
  "select version from supabase_migrations.schema_migrations order by version" | sort -u)

solo_prod=$(comm -13 <(echo "$repo") <(echo "$prod"))
solo_repo=$(comm -23 <(echo "$repo") <(echo "$prod"))

estado=0

if [[ -n "$solo_prod" ]]; then
  echo "APLICADAS EN PROD SIN ARCHIVO EN EL REPO:"
  echo "$solo_prod" | sed 's/^/  /'
  echo "  → recuperá el SQL del ledger y versionalo:"
  echo "    select array_to_string(statements, E'\\n') from supabase_migrations.schema_migrations where version = '...';"
  estado=1
fi

if [[ -n "$solo_repo" ]]; then
  echo "ARCHIVOS EN EL REPO QUE PROD NO CONOCE:"
  echo "$solo_repo" | sed 's/^/  /'
  echo "  → o falta aplicarlas, o se aplicaron con otro timestamp (renombrá el archivo al"
  echo "    version del ledger; el ledger manda, es lo que realmente corrió)."
  estado=1
fi

if [[ $estado -eq 0 ]]; then
  echo "Sin drift: $(echo "$repo" | wc -l | tr -d ' ') migraciones, repo y prod idénticos."
fi

exit $estado
