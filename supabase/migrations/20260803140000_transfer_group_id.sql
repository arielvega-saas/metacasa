-- Transferencias entre cuentas propias: se vinculan las dos piernas.
--
-- HOY: mover $500.000 entre cuentas propias crea un GASTO en origen y un INGRESO en destino, sin
-- ningún vínculo. Los agregados los suman como plata real: +500.000 a ingresos Y +500.000 a
-- gastos. Hunde el health score, mete "Transferencia" como categoría top del donut y consume el
-- sobre si existe uno con ese nombre.
--
-- POR QUÉ UNA COLUMNA Y NO UN TIPO NUEVO ('TRANSFERENCIA' en TxType) — se evaluó y se descartó:
--
--   1. `TxType` en iOS es `enum: String, Codable` SIN init(from:) tolerante, y el decode es de
--      array completo. UNA sola fila con un valor desconocido hace fallar el decode ENTERO: la
--      app 1.0.3 publicada se queda con Home, Movimientos y Reportes vacíos. Flutter igual
--      (`$enumDecode` sin `unknownValue`). No es un riesgo: es determinista.
--   2. Hay SEIS lugares con la forma `type = 'GASTO' ? -amount : +amount` — o sea, "todo lo que
--      no es gasto suma": `account_balances`, el snapshot diario, `AccountBalanceService`, el PDF
--      exporter, `listAccountsWithBalance` y `shared.ts`. Con un tercer tipo, la pierna de origen
--      deja de restar y pasa a SUMAR: el saldo de la cuenta se va +2× el monto, sin error y con
--      un número plausible.
--   3. Un tipo nuevo tampoco elimina la necesidad del vínculo: seguirías sin saber qué pierna va
--      con cuál, así que no podrías mostrar una fila única ni borrar las dos juntas.
--
-- La columna es nullable y sin default: los clientes viejos la reciben como una key JSON extra y
-- la ignoran (`Transaction.CodingKeys` en iOS es explícito y no la incluye).
--
-- Impacto de datos: CERO transferencias existentes en la base (verificado). El backfill es no-op.
--
-- REGLA DE AGREGACIÓN (va también en metacasa-web/AGENTS_CONTRACT.md):
--   * Todo agregado de INGRESO / GASTO / categoría / health score / insights filtra
--     `transfer_group_id IS NULL`.
--   * Todo agregado de SALDO POR CUENTA (account_balances, snapshots, net worth,
--     listAccountsWithBalance, AccountBalanceService) NO filtra: ahí las dos piernas son el
--     mecanismo por el que la plata se mueve de una cuenta a la otra.
--   * El listado de movimientos no filtra, pero colapsa cada grupo en una sola fila "A → B".
--
-- Aplicada en prod el 2026-08-03.

alter table public.transactions
  add column if not exists transfer_group_id uuid;

comment on column public.transactions.transfer_group_id is
  'Vincula las dos piernas de una transferencia entre cuentas propias. NULL = movimiento normal. '
  'Los agregados de ingreso/gasto/categoria/score DEBEN filtrar `transfer_group_id is null`. '
  'Los agregados de SALDO POR CUENTA no filtran: ahi las dos piernas son el mecanismo.';

create index if not exists idx_transactions_transfer_group
  on public.transactions (transfer_group_id)
  where transfer_group_id is not null;

-- El índice que van a usar TODOS los agregados una vez que filtren.
create index if not exists idx_transactions_household_nontransfer
  on public.transactions (household_id, date desc)
  where transfer_group_id is null;

-- Diagnóstico: una transferencia sana tiene exactamente 2 piernas que se compensan.
-- Vacía = todo bien. Enganchable al healthcheck.
create or replace view public.v_transfer_health as
select transfer_group_id,
       household_id,
       count(*) as piernas,
       count(*) filter (where type = 'GASTO')   as gastos,
       count(*) filter (where type = 'INGRESO') as ingresos,
       sum(case when type = 'GASTO' then -amount else amount end) as desbalance
from public.transactions
where transfer_group_id is not null
group by 1, 2
having count(*) <> 2
    or sum(case when type = 'GASTO' then -amount else amount end) <> 0;
