import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metacasa/data/repositories/transaction_repository.dart';
import 'package:metacasa/models/transaction.dart';

/// Tests de la invariante central de las transferencias.
///
/// **Agregarle un par de transferencia a un conjunto de movimientos no puede cambiar ningún
/// agregado de ingreso, gasto o categoría** — la plata nunca salió del hogar.
///
/// La contra-invariante importa igual: sí tiene que mover exactamente dos saldos de cuenta, en
/// direcciones opuestas. Es la que evita que un filtro demasiado entusiasta rompa los saldos, que
/// sería un bug peor que el original: los saldos son la única fuente de verdad de cuánta plata hay
/// realmente en cada cuenta.
///
/// Espeja `TransferAggregationTests` de iOS a propósito. Los tres clientes tienen que dar el mismo
/// número sobre los mismos datos; tener el mismo test escrito en los tres es lo que lo sostiene.
void main() {
  final Decimal cienMil = Decimal.fromInt(100000);
  final Decimal treintaMil = Decimal.fromInt(30000);
  final Decimal medioMillon = Decimal.fromInt(500000);

  Transaction tx(
    TxType type,
    Decimal amount, {
    String category = 'Alimentación',
    String? accountId,
    String? transferGroupId,
  }) =>
      Transaction(
        id: 'tx-${DateTime.now().microsecondsSinceEpoch}-$category-$type',
        householdId: 'h1',
        userId: 'u1',
        accountId: accountId,
        type: type,
        amount: amount,
        category: category,
        date: DateTime.utc(2026, 5, 10, 12),
        transferGroupId: transferGroupId,
      );

  /// Movimientos reales: 100.000 de ingreso, 30.000 de gasto.
  List<Transaction> movimientosReales() => <Transaction>[
        tx(TxType.ingreso, cienMil, category: 'Sueldo'),
        tx(TxType.gasto, treintaMil),
      ];

  /// Las dos piernas de mover 500.000 entre cuentas propias.
  List<Transaction> piernas({required String origen, required String destino}) {
    const String grupo = 'grupo-1';
    return <Transaction>[
      tx(TxType.gasto, medioMillon,
          category: 'Transferencia', accountId: origen, transferGroupId: grupo),
      tx(TxType.ingreso, medioMillon,
          category: 'Transferencia', accountId: destino, transferGroupId: grupo),
    ];
  }

  const TransactionRepository repo = TransactionRepository();

  group('invariante: los agregados NO se mueven', () {
    test('excludingTransfers deja sólo los movimientos reales', () {
      final List<Transaction> conT = <Transaction>[
        ...movimientosReales(),
        ...piernas(origen: 'a', destino: 'b'),
      ];
      expect(conT.length, 4);
      expect(conT.excludingTransfers.length, 2);
    });

    test('los totales no se inflan', () {
      final TransactionTotals sinT = repo.totalsOf(movimientosReales());
      final TransactionTotals conT = repo.totalsOf(<Transaction>[
        ...movimientosReales(),
        ...piernas(origen: 'a', destino: 'b'),
      ]);

      expect(conT.ingresos, sinT.ingresos, reason: 'los ingresos no pueden moverse');
      expect(conT.gastos, sinT.gastos, reason: 'los gastos no pueden moverse');
      expect(conT.ingresos, cienMil);
      expect(conT.gastos, treintaMil, reason: 'sin el filtro darían 530.000');
    });

    test('"Transferencia" no aparece como categoría de gasto', () {
      final List<Transaction> conT = <Transaction>[
        ...movimientosReales(),
        ...piernas(origen: 'a', destino: 'b'),
      ];
      final Map<String, Decimal> porCategoria = <String, Decimal>{};
      for (final Transaction t in conT.excludingTransfers) {
        if (t.type != TxType.gasto) continue;
        porCategoria[t.category] =
            (porCategoria[t.category] ?? Decimal.zero) + t.amount;
      }
      expect(porCategoria['Transferencia'], isNull);
      expect(porCategoria['Alimentación'], treintaMil);
    });

    test('una transferencia no salva la racha de un día sin actividad real', () {
      expect(piernas(origen: 'a', destino: 'b').excludingTransfers, isEmpty);
    });
  });

  group('contra-invariante: los saldos SÍ se mueven', () {
    test('la cuenta de origen baja y la de destino sube', () {
      final List<Transaction> ps = piernas(origen: 'a', destino: 'b');

      // Los saldos por cuenta NO filtran: acá las dos piernas son el mecanismo.
      Decimal saldo(String cuenta) => ps
          .where((Transaction t) => t.accountId == cuenta)
          .fold(Decimal.zero, (Decimal acc, Transaction t) =>
              t.type == TxType.gasto ? acc - t.amount : acc + t.amount);

      expect(saldo('a'), -medioMillon);
      expect(saldo('b'), medioMillon);
      expect(saldo('a') + saldo('b'), Decimal.zero,
          reason: 'el patrimonio del hogar no cambia: la plata sigue adentro');
    });
  });

  group('bordes', () {
    test('sin transferencias no cambia nada', () {
      final List<Transaction> txs = movimientosReales();
      expect(txs.excludingTransfers.length, txs.length);
    });

    test('lista vacía', () {
      expect(<Transaction>[].excludingTransfers, isEmpty);
    });

    test('una pierna huérfana también se excluye', () {
      // Si por un bug quedara una sola pierna, tampoco debe contar como ingreso
      // o gasto real. El desbalance se detecta con `v_transfer_health` en el
      // backend, no acá.
      final List<Transaction> huerfana = <Transaction>[
        tx(TxType.gasto, medioMillon,
            category: 'Transferencia', transferGroupId: 'grupo-huerfano'),
      ];
      expect(huerfana.excludingTransfers, isEmpty);
    });

    test('isTransfer distingue las piernas', () {
      expect(piernas(origen: 'a', destino: 'b').every((Transaction t) => t.isTransfer), isTrue);
      expect(movimientosReales().any((Transaction t) => t.isTransfer), isFalse);
    });
  });

  group('decodificación', () {
    test('una fila sin transfer_group_id se lee como movimiento normal', () {
      final Transaction t = Transaction.fromJson(<String, dynamic>{
        'id': 'x',
        'household_id': 'h1',
        'user_id': 'u1',
        'type': 'GASTO',
        'amount': '1500.50',
        'category': 'Alimentación',
        'date': '2026-05-10T12:00:00Z',
      });
      expect(t.transferGroupId, isNull);
      expect(t.isTransfer, isFalse);
    });

    test('una fila CON transfer_group_id no rompe el decode', () {
      // La columna es aditiva justamente para esto: un cliente que no la conociera
      // ignoraría la key. Un valor NUEVO de enum, en cambio, haría fallar el decode
      // de la lista entera y la pantalla quedaría vacía.
      final Transaction t = Transaction.fromJson(<String, dynamic>{
        'id': 'x',
        'household_id': 'h1',
        'user_id': 'u1',
        'type': 'GASTO',
        'amount': '500000',
        'category': 'Transferencia',
        'date': '2026-05-10T12:00:00Z',
        'transfer_group_id': 'grupo-1',
      });
      expect(t.transferGroupId, 'grupo-1');
      expect(t.isTransfer, isTrue);
    });
  });
}
