import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';

part 'bill.freezed.dart';
part 'bill.g.dart';

/// Estado del vencimiento.
enum BillStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('paid')
  paid,
  @JsonValue('skipped')
  skipped;

  String get label => switch (this) {
        BillStatus.pending => 'Pendiente',
        BillStatus.paid => 'Pagado',
        BillStatus.skipped => 'Saltado',
      };
}

/// Estado visual según `dueDate` y `status`. Refleja los colores del web.
enum BillUrgencyLevel {
  paid,
  overdue, // pasada, no pagada
  dueToday, // hoy
  dueSoon, // 1-3 días
  upcoming, // 4-14 días
  future, // >14 días
  skipped,
}

/// Vencimiento (bill) — obligación de pago con fecha específica.
///
/// Espejo 1:1 de la tabla REAL `public.bills` (verificada contra la DB viva,
/// que está más actualizada que el modelo Swift de iOS). Campos del schema:
/// id, user_id, household_id, title, amount, currency, due_date, status,
/// recurrence_type, reminder_days, amount_original, currency_original,
/// fx_rate_to_base, category, created_at.
@freezed
abstract class Bill with _$Bill {
  const Bill._();

  const factory Bill({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'household_id') required String householdId,
    required String title,
    @DecimalConverter() required Decimal amount,
    @Default('USD') String currency,
    @JsonKey(name: 'due_date') required DateTime dueDate,
    @Default(BillStatus.pending) BillStatus status,
    @Default('') String category,
    @JsonKey(name: 'recurrence_type') String? recurrenceType,
    @JsonKey(name: 'reminder_days') int? reminderDays,
    @JsonKey(name: 'amount_original')
    @DecimalNullConverter()
    Decimal? amountOriginal,
    @JsonKey(name: 'currency_original') String? currencyOriginal,
    @JsonKey(name: 'fx_rate_to_base')
    @DecimalNullConverter()
    Decimal? fxRateToBase,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Bill;

  factory Bill.fromJson(Map<String, dynamic> json) => _$BillFromJson(json);

  /// `true` si el vencimiento se repite (tiene `recurrence_type` definido).
  bool get isRecurring => recurrenceType != null && recurrenceType!.isNotEmpty;

  /// Días hasta el vencimiento (negativo si ya pasó). Normalizado a inicio
  /// de día, como en iOS.
  int get daysUntilDue {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  /// Nivel de urgencia visual. Port de `Bill.urgency` en iOS.
  BillUrgencyLevel get urgency {
    if (status == BillStatus.paid) return BillUrgencyLevel.paid;
    if (status == BillStatus.skipped) return BillUrgencyLevel.skipped;
    final int days = daysUntilDue;
    if (days < 0) return BillUrgencyLevel.overdue;
    if (days == 0) return BillUrgencyLevel.dueToday;
    if (days <= 3) return BillUrgencyLevel.dueSoon;
    if (days <= 14) return BillUrgencyLevel.upcoming;
    return BillUrgencyLevel.future;
  }
}
