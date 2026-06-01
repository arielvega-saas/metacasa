import Image from "next/image";
import { cn } from "@/lib/utils";

/** Ícono de marca REAL de Home Finance (el mismo que la app iOS/Android). */
export function LogoMark({ className }: { className?: string }) {
  return (
    <Image
      src="/logo.png"
      alt="Home Finance"
      width={48}
      height={48}
      priority
      className={cn("h-9 w-9 rounded-[11px] object-contain", className)}
    />
  );
}

/** Logo completo (ícono real + wordmark). */
export function Logo({
  className,
  textClassName,
  markClassName,
}: {
  className?: string;
  textClassName?: string;
  markClassName?: string;
}) {
  return (
    <div className={cn("flex items-center gap-2.5", className)}>
      <LogoMark className={markClassName} />
      <span
        className={cn(
          "text-[17px] font-semibold tracking-tight text-foreground",
          textClassName,
        )}
      >
        Home <span className="text-text-muted font-normal">Finance</span>
      </span>
    </div>
  );
}
