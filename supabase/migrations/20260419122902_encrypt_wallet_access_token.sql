-- Migration: encrypt_wallet_access_token
-- Aplicada: 2026-04-19
--
-- Cifra connected_wallets.access_token con pgcrypto + Vault.
-- Motivo: tokens OAuth en texto plano = riesgo critico en app de finanzas.
-- Post-migracion: edge function wallet-proxy debe usar public.get_wallet_access_token(wid).
-- App cliente debe enviar wallet_id al proxy en lugar de token.

-- 1. Crear encryption key en Vault (idempotente)
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'metacasa_wallet_token_key') then
    perform vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'metacasa_wallet_token_key',
      'Key for encrypting OAuth access tokens in connected_wallets (32 bytes hex, AES)'
    );
  end if;
end $$;

-- 2. Helper interno para leer la key (service_role / propietario)
create or replace function public.wallet_encryption_key() returns text
language sql
security definer
set search_path = public, vault
as $$
  select decrypted_secret
  from vault.decrypted_secrets
  where name = 'metacasa_wallet_token_key'
  limit 1
$$;

revoke all on function public.wallet_encryption_key() from public, authenticated, anon;

-- 3. Columna cifrada
alter table public.connected_wallets
  add column if not exists access_token_encrypted bytea;

-- 4. Migrar tokens existentes (antes del trigger para evitar doble cifrado)
update public.connected_wallets
set access_token_encrypted = pgp_sym_encrypt(
  access_token,
  public.wallet_encryption_key()
)
where access_token is not null
  and access_token_encrypted is null;

-- 5. Trigger: cifrar al escribir access_token y limpiar plaintext
create or replace function public.encrypt_wallet_access_token_tg() returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.access_token is not null then
    new.access_token_encrypted := pgp_sym_encrypt(
      new.access_token,
      public.wallet_encryption_key()
    );
    new.access_token := null;
  end if;
  return new;
end;
$$;

drop trigger if exists encrypt_access_token_trigger on public.connected_wallets;
create trigger encrypt_access_token_trigger
  before insert or update of access_token on public.connected_wallets
  for each row execute function public.encrypt_wallet_access_token_tg();

-- 6. Function para que service_role recupere el token descifrado
create or replace function public.get_wallet_access_token(wid uuid) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  tok text;
begin
  select pgp_sym_decrypt(access_token_encrypted, public.wallet_encryption_key())
  into tok
  from public.connected_wallets
  where id = wid;
  return tok;
end;
$$;

revoke all on function public.get_wallet_access_token(uuid) from public, authenticated, anon;

-- 7. Limpiar plaintext en rows migradas
update public.connected_wallets
set access_token = null
where access_token is not null and access_token_encrypted is not null;

comment on column public.connected_wallets.access_token is
  'DEPRECATED desde 2026-04-19: tokens se almacenan cifrados en access_token_encrypted. Usar public.get_wallet_access_token(id) via service_role para recuperar el plaintext.';
comment on column public.connected_wallets.access_token_encrypted is
  'OAuth access_token cifrado con AES (pgp_sym_encrypt) usando key en Vault (metacasa_wallet_token_key). Nunca exponer a clientes.';
