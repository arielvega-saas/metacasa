import Link from "next/link";
import {
  ArrowRight,
  BarChart3,
  CalendarClock,
  Check,
  ChevronDown,
  Globe2,
  ShieldCheck,
  Sparkles,
  Target,
  TrendingUp,
  Users,
  Wallet,
  type LucideIcon,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { APP_STORE_URL } from "./constants";

/**
 * Landing de marketing de Home Finance (raíz `/`, solo sin sesión).
 * Contenido portado de `marketing/Landing/index.html`, rebrandeado 100%
 * Midnight Sage con los tokens del design system. Animaciones en CSS puro.
 */

/* ============================== Datos ============================== */

const TRUST_CHIPS: { icon: LucideIcon; label: string }[] = [
  { icon: ShieldCheck, label: "Privacidad primero" },
  { icon: Globe2, label: "Multi-moneda" },
  { icon: Users, label: "Para todo el hogar" },
  { icon: Sparkles, label: "Con IA" },
];

const STATS: { num: string; caption: string }[] = [
  { num: "1", caption: "app para todo el hogar" },
  { num: "3", caption: "idiomas · ES / EN / PT" },
  { num: "100%", caption: "privada y cifrada" },
  { num: "7", caption: "días de Premium gratis" },
];

const FEATURES: { icon: LucideIcon; title: string; body: string }[] = [
  {
    icon: Wallet,
    title: "Presupuesto del hogar",
    body: "Sobres por categoría y disponible real del mes. Cada peso en su lugar, sin planillas ni vueltas.",
  },
  {
    icon: Globe2,
    title: "Multi-moneda con FX",
    body: "Cargá en pesos, dólares o la moneda que uses: todo se convierte a tu moneda base con la tasa que elijas.",
  },
  {
    icon: Target,
    title: "Metas con fecha",
    body: "Definí cuánto va a ahorro e inversión cada mes, con porcentajes flexibles y un plan visual claro.",
  },
  {
    icon: CalendarClock,
    title: "Vencimientos y cuotas",
    body: "Servicios, tarjetas, deudas y cuotas bajo control. Nunca más un pago olvidado.",
  },
  {
    icon: BarChart3,
    title: "Reportes claros",
    body: "Salud financiera de 0 a 100, comparativa mes a mes y tendencias anuales que se entienden de un vistazo.",
  },
  {
    icon: Sparkles,
    title: "Asistente IA",
    body: "Preguntale “¿en qué gasté de más?”, sacale foto a un recibo o dictale un gasto. Te explica, no te complica.",
  },
];

const STEPS: { title: string; body: string }[] = [
  {
    title: "Creá tu cuenta",
    body: "Registrate gratis en la web o bajate la app del App Store. Tu hogar queda listo en segundos.",
  },
  {
    title: "Sumá a tu familia",
    body: "Invitá a tu pareja o familia. Cada uno carga lo suyo, todos ven el mismo saldo.",
  },
  {
    title: "Mirá tu disponible",
    body: "Cargá gastos o sacale foto a un recibo. La IA ordena, vos decidís.",
  },
];

const FREE_FEATURES = [
  "Ingresos, gastos y movimientos del hogar",
  "Presupuesto por sobres y metas",
  "Hogar compartido y multi-moneda",
  "Asistente IA con uso limitado",
];

// Copy de beneficios Premium tomado de APP_STORE_COPY.md (sección PLAN PREMIUM).
const PREMIUM_FEATURES = [
  "Asistente IA ilimitado + modo voz",
  "Reportes avanzados",
  "Importación XLSX y exportación CSV, PDF y JSON",
  "Backup automático",
  "Más control para hogares grandes",
];

const FAQS: { q: string; a: string }[] = [
  {
    q: "¿Puedo usarla con mi pareja o mi familia?",
    a: "Sí, para eso nació. Invitás a quien quieras a tu hogar: cada uno carga sus movimientos y todos ven el mismo saldo compartido. Ideal para dejar de discutir por la plata.",
  },
  {
    q: "¿Funciona con más de una moneda?",
    a: "Sí. Cargás cada movimiento en su moneda original y la app lo convierte a la moneda base de tu hogar con la tasa que definas. Perfecta para hogares que manejan pesos y dólares a la vez.",
  },
  {
    q: "¿Qué incluye la prueba de 7 días?",
    a: "Todo Premium desbloqueado, sin compromiso: asistente IA ilimitado, modo voz, reportes avanzados, importación y exportación, y backup automático. Después decidís, sin apuro.",
  },
  {
    q: "¿Mis datos están seguros?",
    a: "Privacidad primero: cifrado en tránsito y en reposo, Face ID / Touch ID opcional en la app y nada de vender tus datos. Vos elegís qué se procesa en la nube.",
  },
  {
    q: "¿Necesito un iPhone o puedo usar la web?",
    a: "Las dos cosas: la app está en el App Store y la web app funciona en cualquier navegador, con los mismos datos sincronizados. Android está en camino.",
  },
];

/* ============================== Página ============================== */

export function Landing() {
  return (
    <>
      {/* Animaciones CSS puras de la landing (blobs, float, rise). */}
      <style>{`
        @keyframes hf-drift-a { 0%, 100% { transform: translate(-50%, 0) scale(1); } 50% { transform: translate(calc(-50% + 40px), 50px) scale(1.07); } }
        @keyframes hf-drift-b { 0%, 100% { transform: translate(0, 0) scale(1); } 50% { transform: translate(70px, -40px) scale(1.1); } }
        @keyframes hf-drift-c { 0%, 100% { transform: translate(0, 0) scale(1); } 50% { transform: translate(-50px, -30px) scale(1.05); } }
        @keyframes hf-float { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-12px); } }
        @keyframes hf-pulse { 0%, 100% { box-shadow: 0 0 0 3px color-mix(in srgb, var(--mc-sage) 22%, transparent); } 50% { box-shadow: 0 0 0 7px color-mix(in srgb, var(--mc-sage) 6%, transparent); } }
        @keyframes hf-rise { from { opacity: 0; transform: translateY(18px); } to { opacity: 1; transform: none; } }
        .hf-blob-a { animation: hf-drift-a 26s ease-in-out infinite; }
        .hf-blob-b { animation: hf-drift-b 32s ease-in-out infinite; }
        .hf-blob-c { animation: hf-drift-c 38s ease-in-out infinite; }
        .hf-float { animation: hf-float 7s ease-in-out infinite; }
        .hf-float-slow { animation: hf-float 9s ease-in-out infinite; animation-delay: .8s; }
        .hf-dot { animation: hf-pulse 2.4s ease-in-out infinite; }
        .hf-rise-1, .hf-rise-2, .hf-rise-3, .hf-rise-4 { animation: hf-rise .8s cubic-bezier(.16, 1, .3, 1) both; }
        .hf-rise-2 { animation-delay: .08s; }
        .hf-rise-3 { animation-delay: .16s; }
        .hf-rise-4 { animation-delay: .24s; }
        @media (prefers-reduced-motion: reduce) {
          .hf-blob-a, .hf-blob-b, .hf-blob-c, .hf-float, .hf-float-slow, .hf-dot,
          .hf-rise-1, .hf-rise-2, .hf-rise-3, .hf-rise-4 { animation: none; }
        }
        @media (prefers-reduced-motion: no-preference) { html { scroll-behavior: smooth; } }
      `}</style>

      {/* Campo de fondo animado (blobs sage/champagne, muy sutiles) */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 -z-10 overflow-hidden"
      >
        <div className="hf-blob-a bg-primary/8 absolute -top-48 left-1/2 h-[560px] w-[560px] -translate-x-1/2 rounded-full blur-3xl" />
        <div className="hf-blob-b bg-primary/5 absolute top-[38%] -left-44 h-[440px] w-[440px] rounded-full blur-3xl" />
        <div className="hf-blob-c bg-champagne/6 absolute -right-36 -bottom-36 h-[460px] w-[460px] rounded-full blur-3xl" />
      </div>

      {/* ===================== HERO ===================== */}
      <section className="mx-auto max-w-6xl px-5 pt-14 pb-16 sm:px-8 sm:pt-20 lg:pt-24">
        <div className="grid items-center gap-14 lg:grid-cols-[1.05fr_0.95fr]">
          <div>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="glass hairline text-text-muted hover:text-foreground hf-rise-1 inline-flex items-center gap-2.5 rounded-full py-1.5 pr-4 pl-2.5 text-[13px] font-medium transition-colors"
            >
              <span className="hf-dot bg-primary size-2 rounded-full" />
              Disponible en App Store · Android muy pronto
            </a>

            <h1 className="font-num hf-rise-2 mt-6 text-[2.6rem] leading-[1.05] text-balance text-foreground sm:text-6xl">
              Tu plata más clara,{" "}
              <span className="text-champagne italic">
                tu casa más tranquila.
              </span>
            </h1>

            <p className="text-text-muted hf-rise-3 mt-6 max-w-xl text-[17px] leading-relaxed text-pretty">
              Presupuesto del hogar, metas, deudas y multi-moneda en una sola
              app — con un asistente IA que entiende tus números. Probala
              gratis 7 días con todo Premium.
            </p>

            <div className="hf-rise-4 mt-8 flex flex-wrap items-center gap-3">
              <Button asChild size="lg">
                <Link href="/login">
                  Probar gratis
                  <ArrowRight />
                </Link>
              </Button>
              <Button asChild variant="secondary" size="lg">
                <a
                  href={APP_STORE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Descargar en el App Store
                </a>
              </Button>
            </div>

            <div className="hf-rise-4 mt-8 flex flex-wrap gap-2.5">
              {TRUST_CHIPS.map((c) => (
                <span
                  key={c.label}
                  className="hairline text-text-muted inline-flex items-center gap-1.5 rounded-full bg-surface px-3 py-1.5 text-xs font-medium"
                >
                  <c.icon className="text-primary size-3.5" />
                  {c.label}
                </span>
              ))}
            </div>
          </div>

          {/* Mock de la app en un teléfono, 100% CSS con tokens Midnight Sage */}
          <div className="relative mx-auto w-[290px] sm:w-[320px]">
            <div
              aria-hidden
              className="bg-primary/15 absolute -inset-10 -z-10 rounded-full blur-3xl"
            />
            <div className="hf-float sage-glow rounded-[2.6rem] border border-tint-3 bg-inset p-2.5">
              <div className="space-y-3 overflow-hidden rounded-[2.1rem] bg-background p-4 pt-5">
                <div className="flex items-center justify-between px-1">
                  <p className="text-[15px] font-semibold text-foreground">
                    Mi Hogar
                  </p>
                  <span className="bg-primary/12 text-primary rounded-full px-2 py-0.5 text-[10px] font-semibold">
                    2 personas
                  </span>
                </div>

                <div className="glass hairline rounded-[var(--radius-xl)] p-4">
                  <p className="text-text-dim text-[10px] font-semibold tracking-[0.14em] uppercase">
                    Saldo del mes
                  </p>
                  <p className="font-num mt-1 text-[2rem] leading-tight text-foreground">
                    $ 2.494.000
                  </p>
                  <p className="text-income mt-1 flex items-center gap-1 text-xs font-medium">
                    <TrendingUp className="size-3.5" />
                    +12% vs mes anterior
                  </p>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="hairline rounded-[var(--radius-lg)] bg-surface p-3">
                    <p className="text-text-dim text-[10px] font-semibold tracking-wide uppercase">
                      Ingresos
                    </p>
                    <p className="text-income tnum mt-1 text-sm font-semibold">
                      $ 2.500.000
                    </p>
                  </div>
                  <div className="hairline rounded-[var(--radius-lg)] bg-surface p-3">
                    <p className="text-text-dim text-[10px] font-semibold tracking-wide uppercase">
                      Gastos
                    </p>
                    <p className="text-expense tnum mt-1 text-sm font-semibold">
                      -$ 486.000
                    </p>
                  </div>
                </div>

                <div className="hairline flex items-center gap-3 rounded-[var(--radius-lg)] bg-surface p-3">
                  <span className="bg-primary/12 text-primary font-num grid size-9 shrink-0 place-items-center rounded-full text-sm">
                    82
                  </span>
                  <div>
                    <p className="text-text-dim text-[10px] font-semibold tracking-wide uppercase">
                      Salud financiera
                    </p>
                    <p className="text-champagne text-sm font-semibold">
                      Excelente
                    </p>
                  </div>
                </div>

                <div className="hairline rounded-[var(--radius-lg)] bg-surface p-3">
                  <div className="flex items-center justify-between">
                    <p className="text-xs font-medium text-foreground">
                      Supermercado
                    </p>
                    <p className="text-text-dim tnum text-xs">64%</p>
                  </div>
                  <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-tint-2">
                    <div className="bg-primary h-full w-[64%] rounded-full" />
                  </div>
                </div>
              </div>
            </div>

            {/* Chips flotantes */}
            <div className="glass hairline hf-float-slow absolute top-24 -left-8 hidden rounded-[var(--radius-lg)] px-3.5 py-2.5 shadow-xl sm:block">
              <p className="text-text-dim text-[10px] font-semibold tracking-[0.12em] uppercase">
                Disponible del mes
              </p>
              <p className="font-num text-primary text-lg leading-snug">
                $ 952.000
              </p>
            </div>
            <div className="glass hairline hf-float-slow absolute -right-5 bottom-20 hidden items-center gap-2 rounded-full px-3.5 py-2 shadow-xl sm:flex">
              <ShieldCheck className="text-primary size-4" />
              <span className="text-xs font-semibold text-foreground">
                Cifrado
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* ===================== BANDA DE STATS ===================== */}
      <section className="border-y border-border">
        <div className="mx-auto grid max-w-6xl grid-cols-2 gap-x-4 gap-y-8 px-5 py-10 sm:px-8 lg:grid-cols-4">
          {STATS.map((s) => (
            <div key={s.caption} className="text-center">
              <p className="font-num text-champagne text-4xl sm:text-5xl">
                {s.num}
              </p>
              <p className="text-text-muted mt-2 text-[13px] font-medium">
                {s.caption}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* ===================== FEATURES ===================== */}
      <section id="funciones" className="scroll-mt-24">
        <div className="mx-auto max-w-6xl px-5 py-20 sm:px-8 sm:py-28">
          <div className="mx-auto max-w-2xl text-center">
            <p className="text-primary text-[13px] font-semibold tracking-[0.13em] uppercase">
              Por dentro
            </p>
            <h2 className="font-num mt-4 text-4xl leading-tight text-balance text-foreground sm:text-5xl">
              Todo lo que tu hogar necesita, en un solo lugar
            </h2>
            <p className="text-text-muted mt-5 text-[17px] text-pretty">
              Caras, complicadas, para una sola persona o solo en inglés.
              Nosotros hicimos la app que faltaba.
            </p>
          </div>

          <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {FEATURES.map((f) => (
              <div
                key={f.title}
                className="glass hairline rounded-[var(--radius-xl)] p-6 transition-transform duration-300 hover:-translate-y-1"
              >
                <span className="bg-primary/12 text-primary grid size-11 place-items-center rounded-[var(--radius-md)]">
                  <f.icon className="size-5" />
                </span>
                <h3 className="mt-4 text-[17px] font-semibold text-foreground">
                  {f.title}
                </h3>
                <p className="text-text-muted mt-2 text-[15px] leading-relaxed text-pretty">
                  {f.body}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ===================== CÓMO FUNCIONA ===================== */}
      <section id="como-funciona" className="scroll-mt-24 border-t border-border">
        <div className="mx-auto max-w-6xl px-5 py-20 sm:px-8 sm:py-28">
          <div className="mx-auto max-w-2xl text-center">
            <p className="text-primary text-[13px] font-semibold tracking-[0.13em] uppercase">
              En 3 pasos
            </p>
            <h2 className="font-num mt-4 text-4xl leading-tight text-balance text-foreground sm:text-5xl">
              Empezás hoy, en minutos
            </h2>
            <p className="text-text-muted mt-5 text-[17px] text-pretty">
              Sin planillas, sin cursos de finanzas. Entrás y en un rato ya ves
              tu plata clara.
            </p>
          </div>

          <div className="mt-14 grid gap-10 sm:grid-cols-3">
            {STEPS.map((s, i) => (
              <div key={s.title} className="text-center">
                <span className="hairline font-num sage-glow mx-auto grid size-16 place-items-center rounded-[var(--radius-lg)] bg-surface text-2xl text-primary">
                  {i + 1}
                </span>
                <h3 className="mt-5 text-lg font-semibold text-foreground">
                  {s.title}
                </h3>
                <p className="text-text-muted mx-auto mt-2 max-w-xs text-[15px] leading-relaxed text-pretty">
                  {s.body}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ===================== PRICING ===================== */}
      <section id="precios" className="scroll-mt-24 border-t border-border">
        <div className="mx-auto max-w-6xl px-5 py-20 sm:px-8 sm:py-28">
          <div className="mx-auto max-w-2xl text-center">
            <p className="text-primary text-[13px] font-semibold tracking-[0.13em] uppercase">
              Precios
            </p>
            <h2 className="font-num mt-4 text-4xl leading-tight text-balance text-foreground sm:text-5xl">
              Empezá gratis, subí cuando quieras
            </h2>
            <p className="text-text-muted mt-5 text-[17px] text-pretty">
              Al crear tu cuenta probás todo Premium durante 7 días. Después
              decidís, sin apuro.
            </p>
          </div>

          <div className="mx-auto mt-14 grid max-w-4xl gap-6 md:grid-cols-2">
            {/* Free */}
            <div className="glass hairline flex flex-col rounded-[var(--radius-2xl)] p-8">
              <p className="text-text-muted text-sm font-semibold tracking-[0.08em] uppercase">
                Free
              </p>
              <p className="font-num mt-4 text-5xl text-foreground">$ 0</p>
              <p className="text-text-muted mt-2 text-sm">
                Lo esencial para ordenar la plata del hogar.
              </p>
              <ul className="mt-7 space-y-3">
                {FREE_FEATURES.map((f) => (
                  <li key={f} className="flex items-start gap-2.5 text-[15px]">
                    <span className="bg-primary/12 text-primary mt-0.5 grid size-5 shrink-0 place-items-center rounded-full">
                      <Check className="size-3" />
                    </span>
                    <span className="text-foreground">{f}</span>
                  </li>
                ))}
              </ul>
              <Button asChild variant="outline" className="mt-8 w-full">
                <Link href="/login">Crear cuenta gratis</Link>
              </Button>
            </div>

            {/* Premium */}
            <div className="glass sage-glow border-primary/30 relative flex flex-col rounded-[var(--radius-2xl)] border p-8">
              <span className="bg-primary text-primary-foreground absolute top-6 right-6 rounded-full px-3 py-1 text-[11px] font-bold">
                7 días gratis
              </span>
              <p className="text-primary text-sm font-semibold tracking-[0.08em] uppercase">
                Premium
              </p>
              <p className="font-num mt-4 text-3xl leading-snug text-foreground">
                Mensual o anual
              </p>
              <p className="text-text-muted mt-2 text-sm">
                Lo elegís dentro de la app. Cancelás cuando quieras.
              </p>
              <ul className="mt-7 space-y-3">
                {PREMIUM_FEATURES.map((f) => (
                  <li key={f} className="flex items-start gap-2.5 text-[15px]">
                    <span className="bg-primary/12 text-primary mt-0.5 grid size-5 shrink-0 place-items-center rounded-full">
                      <Check className="size-3" />
                    </span>
                    <span className="text-foreground">{f}</span>
                  </li>
                ))}
              </ul>
              <Button asChild className="mt-8 w-full">
                <Link href="/login">Probar 7 días gratis</Link>
              </Button>
            </div>
          </div>

          <p className="text-text-dim mt-8 text-center text-[13px]">
            El período de prueba y la suscripción se gestionan desde la app.
            Cancelás cuando quieras.
          </p>
        </div>
      </section>

      {/* ===================== FAQ ===================== */}
      <section id="faq" className="scroll-mt-24 border-t border-border">
        <div className="mx-auto max-w-3xl px-5 py-20 sm:px-8 sm:py-28">
          <div className="mx-auto max-w-2xl text-center">
            <p className="text-primary text-[13px] font-semibold tracking-[0.13em] uppercase">
              Preguntas frecuentes
            </p>
            <h2 className="font-num mt-4 text-4xl leading-tight text-balance text-foreground sm:text-5xl">
              Lo que todos preguntan
            </h2>
          </div>

          <div className="mt-12 space-y-3">
            {FAQS.map((f) => (
              <details
                key={f.q}
                className="glass hairline group rounded-[var(--radius-xl)] px-6 py-5"
              >
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-[15px] font-semibold text-foreground [&::-webkit-details-marker]:hidden">
                  {f.q}
                  <ChevronDown className="text-text-dim size-4 shrink-0 transition-transform duration-300 group-open:rotate-180" />
                </summary>
                <p className="text-text-muted mt-3 text-[15px] leading-relaxed text-pretty">
                  {f.a}
                </p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ===================== CTA FINAL ===================== */}
      <section className="border-t border-border">
        <div className="mx-auto max-w-6xl px-5 py-20 sm:px-8 sm:py-28">
          <div className="glass hairline relative mx-auto max-w-3xl overflow-hidden rounded-[var(--radius-2xl)] px-6 py-14 text-center sm:px-12">
            <div
              aria-hidden
              className="bg-primary/10 pointer-events-none absolute -top-32 left-1/2 size-96 -translate-x-1/2 rounded-full blur-3xl"
            />
            <p className="text-primary relative text-[13px] font-semibold tracking-[0.13em] uppercase">
              Tu casa más tranquila empieza hoy
            </p>
            <h2 className="font-num relative mt-4 text-4xl leading-tight text-balance text-foreground sm:text-5xl">
              Tu plata más clara,{" "}
              <span className="text-champagne italic">en una sola app</span>
            </h2>
            <p className="text-text-muted relative mx-auto mt-5 max-w-md text-[16px] text-pretty">
              Creá tu hogar en minutos y probá 7 días con todo Premium. iOS y
              web disponibles · Android muy pronto.
            </p>
            <div className="relative mt-8 flex flex-wrap items-center justify-center gap-3">
              <Button asChild size="lg">
                <Link href="/login">
                  Probar gratis
                  <ArrowRight />
                </Link>
              </Button>
              <Button asChild variant="secondary" size="lg">
                <a
                  href={APP_STORE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Descargar en el App Store
                </a>
              </Button>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
