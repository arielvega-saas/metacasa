"use client";

import * as React from "react";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";
import { useT } from "@/components/i18n/locale-provider";

/**
 * Sheet (panel deslizante) sobre Radix Dialog. Soporta lados `bottom`/`right`.
 * Reusa el lenguaje visual Midnight Sage (glass + hairline + safe-area).
 */
const Sheet = DialogPrimitive.Root;
const SheetTrigger = DialogPrimitive.Trigger;
const SheetClose = DialogPrimitive.Close;
const SheetPortal = DialogPrimitive.Portal;

const SheetOverlay = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Overlay>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Overlay>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Overlay
    ref={ref}
    className={cn(
      "fixed inset-0 z-50 bg-scrim backdrop-blur-sm transition-opacity data-[state=closed]:opacity-0 data-[state=open]:opacity-100",
      className,
    )}
    {...props}
  />
));
SheetOverlay.displayName = DialogPrimitive.Overlay.displayName;

const SHEET_SIDES = {
  bottom:
    "inset-x-0 bottom-0 rounded-t-[var(--radius-2xl)] border-t data-[state=closed]:translate-y-full data-[state=open]:translate-y-0",
  right:
    "inset-y-0 right-0 h-full w-80 max-w-[88%] rounded-l-[var(--radius-2xl)] border-l data-[state=closed]:translate-x-full data-[state=open]:translate-x-0",
} as const;

const SheetContent = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Content> & {
    side?: keyof typeof SHEET_SIDES;
  }
>(({ className, children, side = "bottom", ...props }, ref) => {
  const t = useT();
  return (
    <SheetPortal>
      <SheetOverlay />
      <DialogPrimitive.Content
        ref={ref}
        className={cn(
          "glass fixed z-50 flex flex-col gap-1 border-border p-4 shadow-2xl shadow-elevation transition-transform duration-300 ease-out",
          "max-h-[85dvh] overflow-y-auto pb-[max(env(safe-area-inset-bottom),1rem)]",
          SHEET_SIDES[side],
          className,
        )}
        {...props}
      >
        {children}
        <DialogPrimitive.Close className="text-text-muted hover:text-foreground absolute right-3 top-3 flex size-9 items-center justify-center rounded-full outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring/40">
          <X className="size-5" />
          <span className="sr-only">{t("common.close")}</span>
        </DialogPrimitive.Close>
      </DialogPrimitive.Content>
    </SheetPortal>
  );
});
SheetContent.displayName = DialogPrimitive.Content.displayName;

const SheetTitle = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Title>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Title>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Title
    ref={ref}
    className={cn("text-base font-semibold tracking-tight", className)}
    {...props}
  />
));
SheetTitle.displayName = DialogPrimitive.Title.displayName;

const SheetDescription = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Description>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Description>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Description
    ref={ref}
    className={cn("text-text-muted text-sm", className)}
    {...props}
  />
));
SheetDescription.displayName = DialogPrimitive.Description.displayName;

export {
  Sheet,
  SheetTrigger,
  SheetClose,
  SheetContent,
  SheetTitle,
  SheetDescription,
};
