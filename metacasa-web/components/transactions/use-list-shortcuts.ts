"use client";

import * as React from "react";

interface Options {
  /** Cuántas filas hay. Si cambia, el índice activo se recorta. */
  count: number;
  onNew: () => void;
  onOpen: (index: number) => void;
  onToggleSelect: (index: number) => void;
  onClearSelection: () => void;
  /** Id del input de búsqueda que enfoca la barra `/`. */
  searchInputId: string;
}

/**
 * Atajos de teclado de la lista de movimientos.
 *
 * Es lo que separa "una web que anda" de "una herramienta": en la compu uno tiene
 * teclado, y YNAB construyó media reputación sobre esto. Nada de lo de acá tiene
 * sentido en un teléfono, por eso vive sólo en la web.
 *
 *   n        nueva transacción
 *   /        foco en el buscador
 *   ↑ ↓      moverse por las filas
 *   Enter    abrir la fila activa
 *   x        marcar/desmarcar la fila activa
 *   Esc      limpiar la selección
 *
 * Devuelve el índice de la fila activa para que la lista la resalte.
 */
export function useListShortcuts({
  count,
  onNew,
  onOpen,
  onToggleSelect,
  onClearSelection,
  searchInputId,
}: Options) {
  const [activeIndex, setActiveIndex] = React.useState(-1);

  // Si la lista se acorta (filtro, borrado), el índice no puede quedar apuntando
  // a una fila que ya no existe.
  React.useEffect(() => {
    setActiveIndex((i) => (i >= count ? count - 1 : i));
  }, [count]);

  // Las callbacks se leen desde una ref para que el listener se registre UNA vez:
  // si fueran dependencias del efecto, cada render lo desmontaría y remontaría.
  const handlers = React.useRef({ onNew, onOpen, onToggleSelect, onClearSelection });
  React.useEffect(() => {
    handlers.current = { onNew, onOpen, onToggleSelect, onClearSelection };
  });

  React.useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      // Los modificadores son de otros atajos (⌘K abre la paleta de comandos).
      if (e.metaKey || e.ctrlKey || e.altKey) return;

      // Si el usuario está escribiendo, las teclas son suyas. Incluye los
      // contenteditable y cualquier campo dentro de un diálogo abierto.
      const target = e.target as HTMLElement | null;
      if (target) {
        const tag = target.tagName;
        if (
          tag === "INPUT" ||
          tag === "TEXTAREA" ||
          tag === "SELECT" ||
          target.isContentEditable
        ) {
          return;
        }
      }
      // Con un diálogo abierto (alta/edición, confirmación de borrado) la lista de
      // atrás no debe reaccionar: Esc y Enter le pertenecen al diálogo.
      if (document.querySelector('[role="dialog"][data-state="open"]')) return;

      switch (e.key) {
        case "n":
        case "N":
          e.preventDefault();
          handlers.current.onNew();
          break;
        case "/": {
          e.preventDefault();
          const input = document.getElementById(searchInputId);
          if (input instanceof HTMLInputElement) {
            input.focus();
            input.select();
          }
          break;
        }
        case "ArrowDown":
          if (count === 0) break;
          e.preventDefault();
          setActiveIndex((i) => Math.min(i + 1, count - 1));
          break;
        case "ArrowUp":
          if (count === 0) break;
          e.preventDefault();
          setActiveIndex((i) => Math.max(i - 1, 0));
          break;
        case "Enter":
          setActiveIndex((i) => {
            if (i >= 0) {
              e.preventDefault();
              handlers.current.onOpen(i);
            }
            return i;
          });
          break;
        case "x":
        case "X":
          setActiveIndex((i) => {
            if (i >= 0) {
              e.preventDefault();
              handlers.current.onToggleSelect(i);
            }
            return i;
          });
          break;
        case "Escape":
          handlers.current.onClearSelection();
          setActiveIndex(-1);
          break;
      }
    }

    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [count, searchInputId]);

  return { activeIndex, setActiveIndex };
}
