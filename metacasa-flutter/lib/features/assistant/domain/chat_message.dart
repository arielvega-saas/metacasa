/// Contrato del chat del Asistente IA — consumido por la wave de UI (próxima).
///
/// Mantener este archivo limpio y estable: es la SUPERFICIE pública entre el
/// "brain" (controller + tools + proxy) y la pantalla de chat. Plano e
/// inmutable, sin freezed/codegen (igual que el resto de los `*State` de la app).
library;

/// Rol de un mensaje en la conversación.
///
/// - [user]: lo que escribió la persona.
/// - [assistant]: respuesta del modelo (texto en prosa) o el resultado de una
///   tool renderizado como burbuja (ver [ChatMessage.toolKind]).
/// - [system]: mensajes informativos/locales (errores amigables, avisos). NO se
///   envían al modelo como turno `system` — el system prompt real lo arma el
///   controller aparte. Acá `system` es solo para pintar avisos en la UI.
enum ChatRole { user, assistant, system }

/// Clasificación del resultado de una tool, derivada de la convención de
/// emojis que usan los results del [FinanceToolExecutor] (espejo de iOS):
/// `✅` → [success], `⚠️` → [warning], `❌`/“Error” → [error]. Cuando el mensaje
/// no proviene de una tool (texto normal del modelo) es [none].
///
/// La UI usa esto para decidir el chip/acento de la burbuja (sage para success,
/// champagne para warning, coral para error) sin volver a parsear el texto.
enum ToolResultKind { success, warning, error, none }

/// Un mensaje del chat. Inmutable.
///
/// `text` siempre viene ya "rebrandeado" (identidad de modelos de terceros
/// scrubbeada a "MetaCasa IA") y listo para mostrar. Para burbujas de tool,
/// `toolKind` trae la clasificación y `text` el cuerpo del result.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.toolKind = ToolResultKind.none,
    this.isError = false,
    this.createdAt,
  });

  /// Conveniencia: mensaje del usuario.
  const ChatMessage.user(this.text)
      : role = ChatRole.user,
        toolKind = ToolResultKind.none,
        isError = false,
        createdAt = null;

  /// Conveniencia: respuesta de texto del asistente.
  const ChatMessage.assistant(this.text)
      : role = ChatRole.assistant,
        toolKind = ToolResultKind.none,
        isError = false,
        createdAt = null;

  /// Conveniencia: burbuja de error (rol assistant, marcada como error para que
  /// la UI la pinte en coral). Usada cuando el turno falla (sin sesión, rate
  /// limit, red caída, loop excedido).
  const ChatMessage.error(this.text)
      : role = ChatRole.assistant,
        toolKind = ToolResultKind.error,
        isError = true,
        createdAt = null;

  /// Quién emite el mensaje.
  final ChatRole role;

  /// Texto a mostrar (ya rebrandeado / listo para render).
  final String text;

  /// Clasificación si el mensaje es el resultado de una tool; [ToolResultKind.none]
  /// para texto normal.
  final ToolResultKind toolKind;

  /// `true` si la burbuja representa un fallo (degradación amigable del turno).
  final bool isError;

  /// Momento de creación (opcional; la UI puede agrupar/“timestamp” con esto).
  final DateTime? createdAt;

  /// Copia con campos sobrescritos.
  ChatMessage copyWith({
    ChatRole? role,
    String? text,
    ToolResultKind? toolKind,
    bool? isError,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      toolKind: toolKind ?? this.toolKind,
      isError: isError ?? this.isError,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Mapea la convención de emojis de los results de tools a un [ToolResultKind].
  /// `✅` → success · `⚠️` → warning · `❌` o prefijo "Error" → error · resto → none.
  /// Centralizado acá para que controller y UI clasifiquen igual.
  static ToolResultKind kindFromToolResult(String result) {
    final String t = result.trimLeft();
    if (t.startsWith('✅')) return ToolResultKind.success;
    if (t.startsWith('⚠️')) return ToolResultKind.warning;
    if (t.startsWith('❌') || t.startsWith('Error') || t.startsWith('error')) {
      return ToolResultKind.error;
    }
    return ToolResultKind.none;
  }
}
