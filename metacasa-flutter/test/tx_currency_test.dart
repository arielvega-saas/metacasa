import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metacasa/core/finance/tx_currency.dart';
import 'package:metacasa/models/household.dart';
import 'package:metacasa/models/transaction.dart';

/// Tests del constructor que lleva un monto a la moneda base del hogar.
///
/// El caso caro era el escaneo de recibos: guardaba el monto del ticket **sin convertir**,
/// sólo etiquetado con su moneda. Un recibo de USD 100 en un hogar en pesos insertaba
/// `amount = 100`, y como `amount` es la columna que suman todos los agregados, los totales
/// quedaban divididos por la cotización.
///
/// No hay error ni crash: el número que queda es plausible. Por eso los tests van sobre la
/// **invariante** (`amount == amountOriginal * fxRateToBase`) y no sobre valores sueltos.
void main() {
  Map<String, FXRate> tasas(Map<String, Decimal> pares) => pares.map(
        (String k, Decimal v) => MapEntry<String, FXRate>(
          k,
          FXRate(rate: v, updatedAt: '2026-08-03T00:00:00Z', source: 'test'),
        ),
      );

  NewTransactionInput construir(
    Decimal monto,
    String? moneda, {
    required String base,
    required Map<String, FXRate> rates,
  }) =>
      NewTransactionInputConverting.converting(
        householdId: 'h1',
        userId: 'u1',
        type: TxType.gasto,
        amountOriginal: monto,
        currency: moneda,
        baseCurrency: base,
        rates: rates,
        category: 'Alimentación',
        date: DateTime.utc(2026, 5, 10, 12),
      );

  final Decimal cien = Decimal.fromInt(100);
  final Decimal milQuinientos = Decimal.fromInt(1500);

  group('conversión', () {
    test('en la moneda base no se convierte', () {
      final NewTransactionInput i =
          construir(Decimal.fromInt(1000), 'ARS', base: 'ARS', rates: <String, FXRate>{});
      expect(i.amount, Decimal.fromInt(1000));
      expect(i.amountOriginal, Decimal.fromInt(1000));
      expect(i.fxRateToBase, Decimal.one);
    });

    test('sin moneda se asume la base', () {
      final NewTransactionInput i =
          construir(Decimal.fromInt(1000), null, base: 'ARS', rates: <String, FXRate>{});
      expect(i.currencyOriginal, 'ARS');
      expect(i.fxRateToBase, Decimal.one);
    });

    test('el recibo en otra moneda se lleva a base y conserva el original', () {
      final NewTransactionInput i = construir(cien, 'USD',
          base: 'ARS', rates: tasas(<String, Decimal>{'USD': milQuinientos}));
      expect(i.amount, Decimal.fromInt(150000), reason: 'lo que suman los totales');
      expect(i.amountOriginal, cien, reason: "lo que el usuario ve como 'US\$ 100'");
      expect(i.currencyOriginal, 'USD');
      expect(i.fxRateToBase, milQuinientos);
    });

    test('se cumple la invariante amount == amountOriginal * fxRateToBase', () {
      for (final (Decimal monto, Decimal tasa) in <(Decimal, Decimal)>[
        (cien, milQuinientos),
        (Decimal.parse('33.33'), Decimal.parse('1234.56')),
        (Decimal.one, Decimal.parse('0.85')),
      ]) {
        final NewTransactionInput i =
            construir(monto, 'USD', base: 'ARS', rates: tasas(<String, Decimal>{'USD': tasa}));
        expect(i.amount, i.amountOriginal! * i.fxRateToBase!,
            reason: 'con monto $monto y tasa $tasa');
      }
    });

    test('la moneda se normaliza a mayúsculas', () {
      final NewTransactionInput i = construir(cien, 'usd',
          base: 'ars', rates: tasas(<String, Decimal>{'USD': milQuinientos}));
      expect(i.currencyOriginal, 'USD');
      expect(i.amount, Decimal.fromInt(150000));
    });
  });

  group('sin cotización: falla fuerte', () {
    test('tira FxConversionException', () {
      expect(
        () => construir(cien, 'EUR',
            base: 'ARS', rates: tasas(<String, Decimal>{'USD': milQuinientos})),
        throwsA(isA<FxConversionException>()),
      );
    });

    test('NO cae al monto crudo', () {
      // Antes ése era el comportamiento del escaneo de recibos, y el error era
      // exactamente el factor de la cotización.
      NewTransactionInput? r;
      try {
        r = construir(cien, 'EUR', base: 'ARS', rates: <String, FXRate>{});
      } on FxConversionException {
        r = null;
      }
      expect(r, isNull,
          reason: 'fallar es correcto; guardar 100 como si fueran ARS 100 no lo es');
    });

    test('el mensaje nombra las dos monedas', () {
      const FxConversionException e =
          FxConversionException(moneda: 'EUR', base: 'ARS');
      expect(e.toString(), contains('EUR'));
      expect(e.toString(), contains('ARS'));
    });
  });
}
