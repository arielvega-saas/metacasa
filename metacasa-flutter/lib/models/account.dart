import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';

part 'account.freezed.dart';
part 'account.g.dart';

/// Pertenencia de la cuenta dentro del hogar.
/// - `personal`: asignada a una persona (waterfall distribuye remanente).
/// - `shared`: del hogar, gastos compartidos (presupuesto común).
/// - `external`: cuenta externa informativa (no afecta waterfall).
enum AccountOwnership {
  @JsonValue('personal')
  personal,
  @JsonValue('shared')
  shared,
  @JsonValue('external')
  external;

  String get label => switch (this) {
        AccountOwnership.personal => 'Personal',
        AccountOwnership.shared => 'Compartida',
        AccountOwnership.external => 'Externa',
      };
}

/// Tipo de cuenta. Espejo de `AccountType` en iOS.
enum AccountType {
  @JsonValue('checking')
  checking,
  @JsonValue('savings')
  savings,
  @JsonValue('cash')
  cash,
  @JsonValue('credit_card')
  creditCard,
  @JsonValue('investment')
  investment,
  @JsonValue('loan')
  loan,
  @JsonValue('other')
  other;

  String get label => switch (this) {
        AccountType.checking => 'Cuenta corriente',
        AccountType.savings => 'Ahorro',
        AccountType.cash => 'Efectivo',
        AccountType.creditCard => 'Tarjeta de crédito',
        AccountType.investment => 'Inversión',
        AccountType.loan => 'Préstamo',
        AccountType.other => 'Otra',
      };
}

/// Red de la tarjeta de crédito.
enum CardNetwork {
  @JsonValue('visa')
  visa,
  @JsonValue('mastercard')
  mastercard,
  @JsonValue('amex')
  amex,
  @JsonValue('discover')
  discover,
  @JsonValue('other')
  other,
}

/// Cuenta financiera. Espejo 1:1 de `public.accounts`.
@freezed
abstract class Account with _$Account {
  const factory Account({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    required String name,
    required AccountType type,
    required String currency,
    @JsonKey(name: 'starting_balance')
    @DecimalConverter()
    required Decimal startingBalance,
    String? institution,
    @JsonKey(name: 'account_number_last4') String? accountNumberLast4,
    String? icon,
    String? color,
    @JsonKey(name: 'display_order') required int displayOrder,
    @JsonKey(name: 'is_active') required bool isActive,
    String? notes,
    @Default(AccountOwnership.personal) AccountOwnership ownership,
    @JsonKey(name: 'owner_user_id') String? ownerUserId,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}

/// Extensión 1:1 con `public.credit_cards` para cuentas type=creditCard.
@freezed
abstract class CreditCardDetails with _$CreditCardDetails {
  const factory CreditCardDetails({
    @JsonKey(name: 'account_id') required String accountId,
    @JsonKey(name: 'credit_limit')
    @DecimalConverter()
    required Decimal creditLimit,
    @JsonKey(name: 'statement_day') required int statementDay,
    @JsonKey(name: 'due_day') required int dueDay,
    @JsonKey(name: 'interest_rate_monthly')
    @DecimalConverter()
    required Decimal interestRateMonthly,
    @JsonKey(name: 'minimum_payment_pct')
    @DecimalConverter()
    required Decimal minimumPaymentPct,
    @JsonKey(name: 'last_statement_amount')
    @DecimalNullConverter()
    Decimal? lastStatementAmount,
    @JsonKey(name: 'last_statement_date') DateTime? lastStatementDate,
    CardNetwork? network,
  }) = _CreditCardDetails;

  factory CreditCardDetails.fromJson(Map<String, dynamic> json) =>
      _$CreditCardDetailsFromJson(json);
}
