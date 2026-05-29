import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de cuentas financieras (`public.accounts`) + su extensión
/// `public.credit_cards`.
///
/// Port de `AccountService.swift` + `CreditCardService.swift`. Scopeado por
/// `household_id`; RLS lo refuerza server-side.
class AccountRepository {
  const AccountRepository();

  static const String _table = 'accounts';
  static const String _cardsTable = 'credit_cards';

  /// Trae todas las cuentas del hogar ordenadas por `display_order`.
  /// Por defecto solo las activas (espejo del default de iOS
  /// `includingInactive: false`); pasá [includingInactive] = true para
  /// incluir las archivadas.
  Future<List<Account>> fetchAll(
    String householdId, {
    bool includingInactive = false,
  }) async {
    var query = supabase.from(_table).select().eq('household_id', householdId);
    if (!includingInactive) {
      query = query.eq('is_active', true);
    }
    final List<dynamic> rows = await query.order('display_order');
    return rows
        .map((dynamic e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Inserta una cuenta. Mandamos el payload completo del modelo SALVO las
  /// columnas server-generated (`id`, `created_at`, `updated_at`). El resto
  /// (incluido `created_by`) viaja como en el `create` de iOS — el caller
  /// arma el [Account] con su `id` placeholder y `createdBy = userId`.
  Future<Account> insert(Account account) async {
    final Map<String, dynamic> payload = account.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');

    final Map<String, dynamic> row =
        await supabase.from(_table).insert(payload).select().single();
    return Account.fromJson(row);
  }

  /// Actualiza una cuenta. Espejo del `Patch` de `AccountService.update`:
  /// solo campos editables. Se EXCLUYEN: id, household_id, created_by,
  /// created_at, updated_at, account_number_last4, y el par de ownership
  /// (`ownership`/`owner_user_id`) — este último se toca con [updateOwnership],
  /// igual que en iOS. Quedan: name, type, currency, starting_balance,
  /// institution, icon, color, display_order, is_active, notes.
  Future<Account> update(Account account) async {
    final Map<String, dynamic> patch = account.toJson()
      ..remove('id')
      ..remove('household_id')
      ..remove('created_by')
      ..remove('created_at')
      ..remove('updated_at')
      ..remove('account_number_last4')
      ..remove('ownership')
      ..remove('owner_user_id');

    final Map<String, dynamic> row = await supabase
        .from(_table)
        .update(patch)
        .eq('id', account.id)
        .select()
        .single();
    return Account.fromJson(row);
  }

  /// Borra una cuenta por id. (iOS usa `archive` soft-delete vía `is_active`;
  /// acá exponemos el delete duro que pide el contrato + [archive] para el
  /// soft-delete.)
  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }

  /// Soft-delete: marca la cuenta como inactiva (espejo de
  /// `AccountService.archive`).
  Future<void> archive(String id) async {
    await supabase
        .from(_table)
        .update(<String, dynamic>{'is_active': false}).eq('id', id);
  }

  /// Actualiza el ownership (personal/shared/external) y opcionalmente el
  /// owner de la cuenta. Port de `AccountService.updateOwnership`.
  Future<void> updateOwnership(
    String id,
    AccountOwnership ownership, {
    String? ownerUserId,
  }) async {
    await supabase.from(_table).update(<String, dynamic>{
      'ownership': ownership.name,
      'owner_user_id': ownerUserId,
    }).eq('id', id);
  }

  // MARK: - Tarjeta de crédito (extensión 1:1 de la cuenta)

  /// Trae los detalles de TC de una cuenta (o null si no existen).
  /// Port de `CreditCardService.fetchDetails`.
  Future<CreditCardDetails?> fetchCard(String accountId) async {
    final Map<String, dynamic>? row = await supabase
        .from(_cardsTable)
        .select()
        .eq('account_id', accountId)
        .maybeSingle();
    if (row == null) return null;
    return CreditCardDetails.fromJson(row);
  }

  /// Upsert de los detalles de TC (PK = account_id). Port de
  /// `CreditCardService.upsert`. Se EXCLUYEN las columnas server-generated
  /// (`created_at`, `updated_at`); el resto del modelo se manda tal cual.
  Future<CreditCardDetails> upsertCard(CreditCardDetails card) async {
    final Map<String, dynamic> payload = card.toJson()
      ..remove('created_at')
      ..remove('updated_at');

    final Map<String, dynamic> row = await supabase
        .from(_cardsTable)
        .upsert(payload, onConflict: 'account_id')
        .select()
        .single();
    return CreditCardDetails.fromJson(row);
  }
}

/// Provider del repositorio de cuentas.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => const AccountRepository(),
);
