import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';
import 'transaction.dart';

part 'recurring_transaction.freezed.dart';
part 'recurring_transaction.g.dart';

/// Frecuencia de recurrencia.
enum Frequency {
  @JsonValue('daily')
  daily,
  @JsonValue('weekly')
  weekly,
  @JsonValue('monthly')
  monthly,
  @JsonValue('yearly')
  yearly;

  /// Próxima fecha a partir de [date], según la frecuencia.
  /// Port de `Frequency.nextDate(from:)` en iOS.
  DateTime nextDate(DateTime date) => switch (this) {
        Frequency.daily => date.add(const Duration(days: 1)),
        Frequency.weekly => date.add(const Duration(days: 7)),
        Frequency.monthly => DateTime(date.year, date.month + 1, date.day),
        Frequency.yearly => DateTime(date.year + 1, date.month, date.day),
      };
}

/// Transacción recurrente (plantilla que genera movimientos automáticos).
/// Espejo 1:1 de `public.recurring_transactions`.
@freezed
abstract class RecurringTransaction with _$RecurringTransaction {
  const factory RecurringTransaction({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    @JsonKey(name: 'user_id') required String userId,
    required TxType type,
    @DecimalConverter() required Decimal amount,
    required String category,
    String? subcategory,
    String? account,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    @JsonKey(name: 'next_date') DateTime? nextDate,
    String? note,
    required Frequency frequency,
    required bool active,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _RecurringTransaction;

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) =>
      _$RecurringTransactionFromJson(json);
}
