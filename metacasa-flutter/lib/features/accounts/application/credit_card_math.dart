import 'package:decimal/decimal.dart';

/// Matemática pura de tarjeta de crédito. Port 1:1 de los métodos estáticos de
/// `CreditCardService.swift` (iOS). Sin red ni estado: solo cálculo con
/// [Decimal] (la fuente de verdad del dinero) y fechas.
///
/// Tres fórmulas:
/// - [minimumPayment]: pago mínimo sugerido = `statement * clamp(pct, 0, 100)/100`.
/// - [interestIfMinPayment]: interés del mes siguiente si solo pagás el mínimo =
///   `(statement − minimum) * monthlyRate/100`.
/// - [daysUntilDue]: días hasta el próximo `dueDay` (este mes o el que viene).
abstract final class CreditCardMath {
  const CreditCardMath._();

  /// 100 como [Decimal], reutilizado en los dos cálculos de porcentaje.
  static final Decimal _hundred = Decimal.fromInt(100);

  /// Pago mínimo sugerido según el porcentaje configurado. El porcentaje se
  /// clampea a `[0, 100]` antes de dividir (igual que el `max(0, min(100, …))`
  /// del iOS). Devuelve `statement * pct/100`.
  static Decimal minimumPayment({
    required Decimal statementAmount,
    required Decimal percent,
  }) {
    // clamp(percent, 0, 100)
    final Decimal pct = percent < Decimal.zero
        ? Decimal.zero
        : (percent > _hundred ? _hundred : percent);
    // `statement * pct / 100`. La división puede ser de precisión infinita
    // (ej. /3), así que materializamos el racional a Decimal con escala amplia.
    return (statementAmount * pct / _hundred)
        .toDecimal(scaleOnInfinitePrecision: 6);
  }

  /// Interés estimado del mes siguiente si solo se paga el mínimo. Sobre el
  /// saldo que queda (`statement − minimum`) se aplica la tasa mensual:
  /// `balance * monthlyRate/100`. Port de `interestIfMinPayment` de iOS.
  static Decimal interestIfMinPayment({
    required Decimal statementAmount,
    required Decimal minPct,
    required Decimal monthlyRate,
  }) {
    final Decimal minimum =
        minimumPayment(statementAmount: statementAmount, percent: minPct);
    final Decimal balance = statementAmount - minimum;
    return (balance * monthlyRate / _hundred)
        .toDecimal(scaleOnInfinitePrecision: 6);
  }

  /// Días hasta el próximo vencimiento según [dueDay] (ej: 15 → día 15 de este
  /// mes, o del mes siguiente si ya pasó). Clampeado a `≥ 0`. Port de
  /// `daysUntilDue(dueDay:from:)` de iOS, operando sobre fechas locales.
  ///
  /// [from] permite inyectar la fecha actual (test-friendly); default
  /// `DateTime.now()`.
  static int daysUntilDue({required int dueDay, DateTime? from}) {
    final DateTime now = from ?? DateTime.now();
    // Normalizamos "hoy" a medianoche local para contar días calendario enteros
    // (sin que la hora del día sesgue el diff).
    final DateTime today = DateTime(now.year, now.month, now.day);

    // Día de vencimiento de ESTE mes (clamp al último día por si dueDay > días
    // del mes — DateTime normaliza el overflow hacia adelante, así que lo
    // acotamos a mano para mantener el mes correcto).
    DateTime next = _dueDateInMonth(today.year, today.month, dueDay);
    if (next.isBefore(today)) {
      // Ya pasó este mes → el del mes que viene.
      final int nextMonth = today.month == 12 ? 1 : today.month + 1;
      final int nextYear = today.month == 12 ? today.year + 1 : today.year;
      next = _dueDateInMonth(nextYear, nextMonth, dueDay);
    }

    final int diff = next.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Fecha de vencimiento dentro de [year]/[month], acotando [dueDay] al último
  /// día real del mes (evita el rollover de `DateTime(2026, 2, 31)` → marzo).
  static DateTime _dueDateInMonth(int year, int month, int dueDay) {
    final int lastDay = DateTime(year, month + 1, 0).day;
    final int day = dueDay < 1 ? 1 : (dueDay > lastDay ? lastDay : dueDay);
    return DateTime(year, month, day);
  }
}
