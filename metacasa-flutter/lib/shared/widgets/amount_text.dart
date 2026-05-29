import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:metacasa/core/utils/money.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Semántica del monto. Determina signo + color de forma consistente en toda la
/// app. Portado 1:1 del enum `AmountLabel.Kind` del iOS:
///
/// - [gasto]: dinero que SALE. Siempre con signo `-` y color coral (brandDanger).
///   Asume `value >= 0` (la DB guarda positivos; el tipo define la dirección).
/// - [ingreso]: dinero que ENTRA. Sin signo, color sage (brandSuccess).
/// - [balance]: saldo/diferencia que puede ser +/-. El signo lo define el valor;
///   color rojo si negativo, verde si positivo, neutro si cero.
/// - [neutro]: sin signo, color default (textPrimary). Para allocated, target,
///   saldos de cuenta positivos, referencias de monto.
enum AmountKind { gasto, ingreso, balance, neutro }

/// `AmountText` — render de montos con color/signo semántico Midnight Sage.
///
/// Equivalente Flutter del `AmountLabel` del iOS. Formatea vía [Money.format]
/// (paquete `metacasa/core/utils/money.dart`) y aplica las reglas de [AmountKind].
///
/// Single-line, `maxLines: 1`, `overflow: ellipsis` — para no romper layouts
/// angostos en rows/tiles. Para balances hero usar [fitToWidth]: emula el
/// `minimumScaleFactor` del iOS escalando el texto hacia abajo (`FittedBox`)
/// en vez de truncarlo con "…".
///
/// El color del kind PISA cualquier color del [style] provisto (la semántica
/// manda); el resto del `TextStyle` (tamaño, peso, familia) sí se respeta. Si no
/// se pasa `style`, default a `AppText.serifInline` (montos inline editoriales).
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.value,
    required this.currencyCode,
    this.kind = AmountKind.neutro,
    this.obscured = false,
    this.showSign = false,
    this.moneyStyle = MoneyStyle.auto,
    this.style,
    this.locale,
    this.textAlign,
    this.fitToWidth = false,
  });

  /// Monto a mostrar. Para [AmountKind.gasto] se fuerza a negativo (ver iOS).
  final Decimal value;

  /// Código ISO de moneda (ej. "USD", "ARS").
  final String currencyCode;

  /// Semántica que define signo + color.
  final AmountKind kind;

  /// Si true, oculta el monto con `••••` (privacy mode). Conserva el color.
  final bool obscured;

  /// Fuerza el signo `+` en positivos. Solo aplica cuando el kind no impone su
  /// propio signo (ver [_effectiveShowSign]).
  final bool showSign;

  /// Estilo de formato numérico (compact/precise/auto/abbreviated).
  final MoneyStyle moneyStyle;

  /// `TextStyle` base. El color se sobrescribe por el del kind.
  final TextStyle? style;

  /// Locale BCP-47 para el formato (ej. "es-AR"). Default: locale del contexto.
  final String? locale;

  /// Alineación horizontal del texto.
  final TextAlign? textAlign;

  /// Modo hero: si true, el texto se escala hacia abajo para entrar en el ancho
  /// disponible (`FittedBox` scaleDown) en vez de truncarse con "…". Pensado para
  /// balances grandes. Con false se mantiene el comportamiento single-line+ellipsis.
  final bool fitToWidth;

  /// Monto final pasado al formatter. Para [AmountKind.gasto] forzamos negativo
  /// (la DB guarda valor absoluto; la UI exige el `-` explícito). Igual que iOS.
  Decimal get _displayValue {
    if (kind == AmountKind.gasto) {
      return value > Decimal.zero ? -value : value;
    }
    return value;
  }

  /// Para gasto/ingreso el signo lo gobierna el kind (gasto siempre `-`, ingreso
  /// nunca `+`). Para balance/neutro respetamos el `showSign` del caller.
  bool get _effectiveShowSign {
    switch (kind) {
      case AmountKind.gasto:
      case AmountKind.ingreso:
        return false;
      case AmountKind.balance:
      case AmountKind.neutro:
        return showSign;
    }
  }

  Color _color(MidnightSageColors colors) {
    switch (kind) {
      case AmountKind.gasto:
        return colors.brandDanger;
      case AmountKind.ingreso:
        return colors.brandSuccess;
      case AmountKind.balance:
        // `colors.amount` ya implementa: <0 coral, >0 sage, 0 neutro.
        return colors.amount(value.toDouble());
      case AmountKind.neutro:
        return colors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _color(colors);

    // Locale efectivo: el explícito o el del contexto. `Money.format` espera el
    // identificador ICU (`es_AR`), así que normalizamos el BCP-47 (`es-AR`) que
    // devuelve `toLanguageTag()` reemplazando guiones por guiones bajos.
    final effectiveLocale =
        (locale ?? Localizations.localeOf(context).toLanguageTag())
            .replaceAll('-', '_');

    final text = obscured
        ? '••••'
        : Money.format(
            _displayValue,
            currencyCode: currencyCode,
            style: moneyStyle,
            showSign: _effectiveShowSign,
            locale: effectiveLocale,
          );

    // El color del kind pisa el del style provisto; el resto del style se honra.
    final base = style ?? AppText.serifInline(color);
    final resolved = base.copyWith(color: color);

    // Modo hero: el FittedBox escala el texto hacia abajo para que entre en el
    // ancho disponible (sin ellipsis). El Text va a una sola línea natural.
    // `FittedBox` es seguro en `Column`/`ListView` (acota su alto al del texto
    // escalado) y soporta dimensiones intrínsecas, por lo que puede vivir bajo
    // un `IntrinsicHeight` (lo usa `_StatsRow` para igualar la altura de los
    // tiles). El alto sin acotar de un scroll lo gobierna el contenido, NUNCA el
    // FittedBox.
    if (fitToWidth) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: resolved,
          maxLines: 1,
          softWrap: false,
          textAlign: textAlign,
        ),
      );
    }

    return Text(
      text,
      style: resolved,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}
