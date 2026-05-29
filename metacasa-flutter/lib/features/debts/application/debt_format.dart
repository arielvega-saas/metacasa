import 'package:decimal/decimal.dart';

/// Helpers de formato compartidos por la lista y el detalle de Deudas. Ports
/// directos de los `fmt`/`formatted` de los views de iOS y de la lógica de
/// "payoff en N meses → a/m" del `projectionCard`.

/// Porcentaje sin ceros sobrantes (max 2 decimales): `45`, `45.5`, `2.75`.
/// SIN sufijo `%` (el call-site lo agrega donde corresponde). Espejo del
/// `NumberFormatter(.decimal)` con `min=0/max=2` de iOS.
String formatRate(Decimal rate) {
  final double v = rate.toDouble();
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

/// Duración legible de [months] meses como "Xa Ym" / "Ym". Espejo del
/// `years > 0 ? "\(years)a \(rem)m" : "\(rem)m"` del `projectionCard` de iOS.
String formatMonthsDuration(int months) {
  final int years = months ~/ 12;
  final int rem = months % 12;
  return years > 0 ? '${years}a ${rem}m' : '${rem}m';
}

/// Fecha local legible "mes año" (rioplatense): "mayo 2026". Para la fecha de
/// payoff proyectada y el vencimiento.
String formatMonthYear(DateTime date) {
  const List<String> months = <String>[
    '',
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final DateTime d = date.toLocal();
  return '${months[d.month]} ${d.year}';
}

/// Fecha local completa "d de mes de año": "5 de mayo de 2026". Para el
/// vencimiento exacto.
String formatLongDate(DateTime date) {
  const List<String> months = <String>[
    '',
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final DateTime d = date.toLocal();
  return '${d.day} de ${months[d.month]} de ${d.year}';
}
