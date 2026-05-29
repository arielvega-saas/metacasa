import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase(); // no-op si faltan credenciales (modo diseño)
  runApp(const ProviderScope(child: MetaCasaApp()));
}
