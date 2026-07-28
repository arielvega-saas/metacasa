"use client";

import * as React from "react";
import { toast } from "sonner";
import { Sparkles, X, Send, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { useT, useLocale } from "@/components/i18n/locale-provider";

/** Un mensaje del chat en estado local. */
type Message = { id: string; role: "user" | "assistant"; content: string };

/** `t()` del provider (mismo tipo en todo el widget). */
type TFn = ReturnType<typeof useT>;

function newId() {
  return Math.random().toString(36).slice(2);
}

/**
 * Asistente IA flotante, disponible en toda el área autenticada. Un FAB sage
 * abajo a la derecha abre un panel de chat (tema Midnight Sage). El historial
 * vive en estado local y se postea entero a /api/assistant en cada turno.
 */
export function AssistantWidget() {
  const t = useT();
  const locale = useLocale();
  const [open, setOpen] = React.useState(false);
  const [messages, setMessages] = React.useState<Message[]>([]);
  const [input, setInput] = React.useState("");
  const [pending, setPending] = React.useState(false);

  const scrollRef = React.useRef<HTMLDivElement>(null);
  const inputRef = React.useRef<HTMLInputElement>(null);

  // Autoscroll al fondo cuando entran mensajes o aparece el loader.
  React.useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, pending]);

  // Cerrar con Escape; foco al input al abrir.
  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    const t = window.setTimeout(() => inputRef.current?.focus(), 80);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.clearTimeout(t);
    };
  }, [open]);

  const send = React.useCallback(
    async (raw: string) => {
      const text = raw.trim();
      if (!text || pending) return;

      const userMsg: Message = { id: newId(), role: "user", content: text };
      // Snapshot del historial que mandamos al backend (incluye el nuevo turno).
      const history = [...messages, userMsg];
      setMessages(history);
      setInput("");
      setPending(true);

      try {
        const res = await fetch("/api/assistant", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            messages: history.map((m) => ({ role: m.role, content: m.content })),
            locale,
          }),
        });
        const data = (await res.json().catch(() => ({}))) as {
          text?: string;
          error?: string;
        };

        if (!res.ok || !data.text) {
          const msg = data.error ?? t("assistant.genericError");
          toast.error(msg);
          // Devolvemos el texto al input para que no se pierda lo escrito.
          setInput(text);
          setMessages((prev) => prev.filter((m) => m.id !== userMsg.id));
          return;
        }

        setMessages((prev) => [
          ...prev,
          { id: newId(), role: "assistant", content: data.text! },
        ]);
      } catch {
        toast.error(t("assistant.connectionError"));
        setInput(text);
        setMessages((prev) => prev.filter((m) => m.id !== userMsg.id));
      } finally {
        setPending(false);
        inputRef.current?.focus();
      }
    },
    [messages, pending, locale, t],
  );

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    void send(input);
  }

  return (
    <>
      {/* FAB — por encima de la tab bar móvil (que es lg:hidden, ~bottom-0). */}
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-label={open ? t("assistant.closeAria") : t("assistant.openAria")}
        aria-expanded={open}
        className={cn(
          "bg-primary text-primary-foreground sage-glow fixed right-4 z-40 flex size-14 items-center justify-center rounded-full shadow-lg shadow-elevation transition-all hover:brightness-105 active:scale-95 focus-visible:ring-2 focus-visible:ring-ring/60 focus-visible:outline-none",
          // Móvil: arriba de la tab bar (~76px + safe area). Desktop: esquina baja.
          "bottom-[calc(5rem+env(safe-area-inset-bottom))] lg:bottom-6",
        )}
      >
        {open ? <X className="size-6" /> : <Sparkles className="size-6" />}
      </button>

      {open && (
        <AssistantPanel
          t={t}
          messages={messages}
          input={input}
          pending={pending}
          scrollRef={scrollRef}
          inputRef={inputRef}
          onClose={() => setOpen(false)}
          onInputChange={setInput}
          onSubmit={handleSubmit}
          onSuggestion={(s) => void send(s)}
        />
      )}
    </>
  );
}

interface PanelProps {
  t: TFn;
  messages: Message[];
  input: string;
  pending: boolean;
  scrollRef: React.RefObject<HTMLDivElement | null>;
  inputRef: React.RefObject<HTMLInputElement | null>;
  onClose: () => void;
  onInputChange: (v: string) => void;
  onSubmit: (e: React.FormEvent) => void;
  onSuggestion: (s: string) => void;
}

function AssistantPanel({
  t,
  messages,
  input,
  pending,
  scrollRef,
  inputRef,
  onClose,
  onInputChange,
  onSubmit,
  onSuggestion,
}: PanelProps) {
  // Transición de entrada con clases utilitarias estándar (sin plugin de animación).
  const [shown, setShown] = React.useState(false);
  React.useEffect(() => {
    const id = window.requestAnimationFrame(() => setShown(true));
    return () => window.cancelAnimationFrame(id);
  }, []);

  const suggestions = [
    t("assistant.suggestion1"),
    t("assistant.suggestion2"),
    t("assistant.suggestion3"),
  ];

  return (
    <div
      role="dialog"
      aria-modal="false"
      aria-label={t("assistant.dialogAria")}
      className={cn(
        "bg-surface fixed z-40 flex flex-col overflow-hidden border border-border shadow-2xl shadow-elevation",
        // Móvil: lámina casi a pantalla completa, por encima de la tab bar.
        "inset-x-3 bottom-[calc(5rem+env(safe-area-inset-bottom))] top-16 rounded-[var(--radius-xl)]",
        // Desktop: panel acotado anclado a la esquina inferior derecha.
        "lg:inset-auto lg:bottom-24 lg:right-4 lg:top-auto lg:h-[34rem] lg:w-[26rem]",
        // Entrada suave (respeta prefers-reduced-motion vía motion-reduce).
        "transition-all duration-200 ease-out motion-reduce:transition-none",
        shown ? "translate-y-0 opacity-100" : "translate-y-3 opacity-0",
      )}
    >
      {/* Header */}
      <header className="flex items-center justify-between gap-2 border-b border-border px-4 py-3">
        <div className="flex items-center gap-2.5">
          <span className="bg-primary/15 text-primary flex size-8 items-center justify-center rounded-full">
            <Sparkles className="size-4" />
          </span>
          <div className="leading-tight">
            <p className="text-foreground text-sm font-semibold">
              {t("assistant.title")}
            </p>
            <p className="text-text-dim text-[11px]">{t("assistant.subtitle")}</p>
          </div>
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label={t("assistant.closeAria")}
          className="text-text-muted hover:text-foreground rounded-full p-1.5 transition-colors focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:outline-none"
        >
          <X className="size-4" />
        </button>
      </header>

      {/* Mensajes */}
      <div ref={scrollRef} className="flex-1 space-y-4 overflow-y-auto px-4 py-4">
        <AssistantBubble text={t("assistant.welcome")} />

        {messages.map((m) =>
          m.role === "assistant" ? (
            <AssistantBubble key={m.id} text={m.content} />
          ) : (
            <UserBubble key={m.id} text={m.content} />
          ),
        )}

        {pending && (
          <div className="flex items-center gap-2.5">
            <span className="bg-primary/15 text-primary flex size-7 shrink-0 items-center justify-center rounded-full">
              <Sparkles className="size-3.5" />
            </span>
            <span className="text-text-muted bg-surface-2 hairline inline-flex items-center gap-2 rounded-[var(--radius-lg)] px-3 py-2 text-sm">
              <Loader2 className="size-3.5 animate-spin" />
              {t("assistant.thinking")}
            </span>
          </div>
        )}

        {/* Sugerencias: solo en estado inicial. */}
        {messages.length === 0 && !pending && (
          <div className="flex flex-wrap gap-2 pt-1">
            {suggestions.map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => onSuggestion(s)}
                className="text-text-muted hover:text-foreground bg-surface-2 hairline hover:bg-tint-2 rounded-full px-3 py-1.5 text-[13px] transition-colors"
              >
                {s}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Input */}
      <form
        onSubmit={onSubmit}
        className="border-t border-border px-3 py-3 pb-[max(env(safe-area-inset-bottom),0.75rem)]"
      >
        <div className="bg-inset hairline flex items-end gap-2 rounded-[var(--radius-lg)] p-1.5 pl-3.5">
          <input
            ref={inputRef}
            value={input}
            onChange={(e) => onInputChange(e.target.value)}
            placeholder={t("assistant.inputPlaceholder")}
            aria-label={t("assistant.inputAriaLabel")}
            disabled={pending}
            enterKeyHint="send"
            className="text-foreground placeholder:text-text-dim h-9 min-w-0 flex-1 bg-transparent text-sm outline-none disabled:opacity-60"
          />
          <Button
            type="submit"
            size="icon"
            aria-label={t("assistant.send")}
            disabled={pending || !input.trim()}
            className="size-9 shrink-0 rounded-[var(--radius-md)]"
          >
            {pending ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              <Send className="size-4" />
            )}
          </Button>
        </div>
      </form>
    </div>
  );
}

function AssistantBubble({ text }: { text: string }) {
  return (
    <div className="flex items-start gap-2.5">
      <span className="bg-primary/15 text-primary mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-full">
        <Sparkles className="size-3.5" />
      </span>
      <div className="bg-surface-2 hairline text-foreground max-w-[85%] whitespace-pre-wrap rounded-[var(--radius-lg)] rounded-tl-sm px-3.5 py-2.5 text-sm leading-relaxed">
        {text}
      </div>
    </div>
  );
}

function UserBubble({ text }: { text: string }) {
  return (
    <div className="flex justify-end">
      <div className="bg-primary/15 text-foreground max-w-[85%] whitespace-pre-wrap rounded-[var(--radius-lg)] rounded-tr-sm px-3.5 py-2.5 text-sm leading-relaxed">
        {text}
      </div>
    </div>
  );
}
