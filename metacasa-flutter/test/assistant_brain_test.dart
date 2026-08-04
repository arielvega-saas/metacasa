import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:metacasa/features/assistant/data/ai_tool_schemas.dart';
import 'package:metacasa/features/assistant/data/anthropic_proxy_provider.dart';
import 'package:metacasa/features/assistant/domain/ai_money_format.dart';
import 'package:metacasa/features/assistant/domain/ai_prompts.dart';
import 'package:metacasa/features/assistant/domain/chat_message.dart';

/// Tests de las piezas PURAS del "brain" del asistente (sin red ni Supabase):
/// scrub de identidad, formato ISO de montos, clasificación de tool-results,
/// parseo de turnos Anthropic, mensajes de error y catálogo de tools.
void main() {
  group('AiPrompts.rebrand', () {
    test('reescribe modelos de terceros al nombre del asistente', () {
      expect(AiPrompts.rebrand('Soy Claude, tu asistente.'),
          'Soy Asistente de Home Finance, tu asistente.');
      expect(AiPrompts.rebrand('Powered by Anthropic and OpenAI'),
          'Powered by Asistente de Home Finance and Asistente de Home Finance');
      expect(AiPrompts.rebrand('Hecho con GPT-4 y Gemini'),
          'Hecho con Asistente de Home Finance y Asistente de Home Finance');
    });

    test('colapsa menciones contiguas repetidas', () {
      // "Claude (Anthropic)" → dos menciones contiguas → una sola.
      expect(AiPrompts.rebrand('Claude Anthropic responde'),
          'Asistente de Home Finance responde');
    });

    test('no toca texto sin nombres de modelos', () {
      const String s = 'Tu balance del mes es positivo.';
      expect(AiPrompts.rebrand(s), s);
    });

    test('reescribe "modelo de lenguaje"', () {
      expect(AiPrompts.rebrand('Soy un modelo de lenguaje entrenado'),
          'Soy Asistente de Home Finance entrenado');
    });
  });

  group('AiMoney.iso', () {
    test('entero sin decimales, ISO-prefijo y miles', () {
      expect(AiMoney.iso(Decimal.parse('6000'), 'ARS'), 'ARS 6,000');
      expect(AiMoney.iso(Decimal.parse('2500000'), 'ARS'), 'ARS 2,500,000');
      expect(AiMoney.iso(Decimal.parse('100'), 'usd'), 'USD 100');
    });

    test('fracción con hasta 2 decimales', () {
      expect(AiMoney.iso(Decimal.parse('1250.5'), 'USD'), 'USD 1,250.5');
      expect(AiMoney.iso(Decimal.parse('1250.55'), 'USD'), 'USD 1,250.55');
    });
  });

  group('ChatMessage.kindFromToolResult', () {
    test('clasifica por convención de emoji/prefijo', () {
      expect(ChatMessage.kindFromToolResult('✅ Listo'), ToolResultKind.success);
      expect(ChatMessage.kindFromToolResult('⚠️ Ojo con esto'),
          ToolResultKind.warning);
      expect(ChatMessage.kindFromToolResult('❌ Falló'), ToolResultKind.error);
      expect(
          ChatMessage.kindFromToolResult('Error: algo'), ToolResultKind.error);
      expect(ChatMessage.kindFromToolResult('Found 3 transactions.'),
          ToolResultKind.none);
    });
  });

  group('AiTurn.fromJson', () {
    test('extrae texto y stop_reason', () {
      final AiTurn turn = AiTurn.fromJson(<String, dynamic>{
        'content': <dynamic>[
          <String, dynamic>{'type': 'text', 'text': 'Hola'},
        ],
        'stop_reason': 'end_turn',
      });
      expect(turn.text, 'Hola');
      expect(turn.stopReason, 'end_turn');
      expect(turn.toolUses, isEmpty);
      expect(turn.wantsTools, isFalse);
    });

    test('extrae tool_use con input + preserva rawContent', () {
      final AiTurn turn = AiTurn.fromJson(<String, dynamic>{
        'content': <dynamic>[
          <String, dynamic>{'type': 'text', 'text': 'Cargo el gasto.'},
          <String, dynamic>{
            'type': 'tool_use',
            'id': 'toolu_123',
            'name': 'add_transaction',
            'input': <String, dynamic>{
              'type': 'GASTO',
              'amount': 6000,
              'category': 'Alimentación',
            },
          },
        ],
        'stop_reason': 'tool_use',
      });
      expect(turn.stopReason, 'tool_use');
      expect(turn.wantsTools, isTrue);
      expect(turn.toolUses, hasLength(1));
      expect(turn.toolUses.first.id, 'toolu_123');
      expect(turn.toolUses.first.name, 'add_transaction');
      expect(turn.toolUses.first.input['amount'], 6000);
      // rawContent debe contener ambos bloques (se re-inyecta en el loop).
      expect(turn.rawContent, hasLength(2));
      expect(turn.text, 'Cargo el gasto.');
    });
  });

  group('AiException.friendlyMessage', () {
    test('mensajes en español por tipo', () {
      expect(const AiException(AiErrorKind.noSession).friendlyMessage,
          contains('sesión'));
      expect(AiException.rateLimit((daily: 50, monthly: 100)).friendlyMessage,
          contains('límite'));
      expect(AiException.api(500, 'x').friendlyMessage, contains('HTTP 500'));
      expect(const AiException(AiErrorKind.network).friendlyMessage,
          contains('conect'));
      expect(const AiException(AiErrorKind.toolLoop).friendlyMessage,
          contains('vueltas'));
    });
  });

  group('AiToolSchemas', () {
    test('expone las 22 tools con nombres únicos', () {
      final List<Map<String, dynamic>> tools = AiToolSchemas.all();
      expect(tools, hasLength(22));
      final Set<String> names = tools.map((t) => t['name'] as String).toSet();
      expect(names, hasLength(22));
      // Sanity: algunas tools clave presentes.
      expect(
          names,
          containsAll(<String>[
            'add_transaction',
            'query_transactions',
            'get_financial_summary',
            'set_budget_envelope',
            'transfer_between_accounts',
            'validate_cfdi',
            'validate_arca',
          ]));
    });

    test('cada tool tiene input_schema tipo object con required lista', () {
      for (final Map<String, dynamic> t in AiToolSchemas.all()) {
        expect(t['name'], isA<String>());
        expect(t['description'], isA<String>());
        final Map<String, dynamic> schema =
            t['input_schema'] as Map<String, dynamic>;
        expect(schema['type'], 'object');
        expect(schema['properties'], isA<Map<String, dynamic>>());
        expect(schema['required'], isA<List<dynamic>>());
      }
    });
  });

  group('AiPrompts.build', () {
    test('inyecta moneda, nombre hablado y bloque de contexto', () {
      final String prompt = AiPrompts.build(
        financialContextBlock:
            '=== LIVE USER FINANCIAL DATA ===\n\nHousehold: Casa · Currency: ARS',
        currency: 'ARS',
      );
      expect(prompt, contains('Home Finance'));
      expect(prompt, contains('The household currency is **ARS**'));
      expect(prompt, contains('say "pesos"'));
      expect(prompt, contains('=== LIVE USER FINANCIAL DATA ==='));
      expect(prompt, contains('=== APP KNOWLEDGE BASE ==='));
    });

    test('omite el bloque de datos cuando viene vacío', () {
      final String prompt =
          AiPrompts.build(financialContextBlock: '', currency: 'USD');
      expect(prompt, contains('say "dólares"'));
      expect(prompt, isNot(contains('LIVE USER FINANCIAL DATA')));
    });
  });
}
