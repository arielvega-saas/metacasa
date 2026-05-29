import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:metacasa/app.dart';

void main() {
  testWidgets(
      'Sin backend (test env) el gate resuelve a unauthenticated → muestra la pantalla de acceso',
      (WidgetTester tester) async {
    // En `flutter test` no hay credenciales Supabase (`Env.hasSupabase` es
    // false), así que `initSupabase()` no corre y el gate arranca en
    // `AppGate.unauthenticated`. El router redirige al gate y `RootGate` pinta
    // la `AuthFlowScreen`.
    await tester.pumpWidget(const ProviderScope(child: MetaCasaApp()));
    // Bombear hasta estabilizar (redirect del gate → /gate → AuthFlowScreen).
    await tester.pumpAndSettle();

    // CTA primario de login.
    expect(find.text('Iniciar sesión'), findsOneWidget);

    // El campo de email (label uppercase del AuthTextField) y un TextField real.
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    // Links de acceso: recuperar contraseña + cambiar a registro.
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
