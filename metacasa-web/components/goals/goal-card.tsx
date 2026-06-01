"use client";

import * as React from "react";
import { toast } from "sonner";
import {
  MoreHorizontal,
  Plus,
  Pencil,
  CheckCircle2,
  CalendarClock,
  Trophy,
} from "lucide-react";
import { format } from "date-fns";
import { es, enUS, ptBR } from "date-fns/locale";
import type { Locale as DateFnsLocale } from "date-fns";
import { Card } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@/components/ui/dropdown-menu";
import { Amount } from "@/components/finance/amount";
import { GoalDialog } from "@/components/goals/goal-dialog";
import { ContributionDialog } from "@/components/goals/contribution-dialog";
import { goalIconFor } from "@/components/goals/goal-icon";
import { completeGoalAction } from "@/lib/actions/goals";
import { formatMoney } from "@/lib/money";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import type { Locale } from "@/lib/i18n/config";
import type { Tables } from "@/lib/database.types";

/** Mapa de locale de la app → locale de date-fns para formatear fechas. */
const DATE_LOCALES: Record<Locale, DateFnsLocale> = { es, en: enUS, pt: ptBR };

interface GoalCardProps {
  goal: Tables<"goals">;
  defaultCurrency: string;
}

/** Card premium de una meta de ahorro con progreso y acciones. */
export function GoalCard({ goal, defaultCurrency }: GoalCardProps) {
  const t = useT();
  const locale = useLocale();
  const [contribOpen, setContribOpen] = React.useState(false);
  const [editOpen, setEditOpen] = React.useState(false);
  const [pending, startTransition] = React.useTransition();

  const currency = goal.currency || defaultCurrency;
  const current = Number(goal.current_amount);
  const target = Number(goal.target_amount);
  const remaining = Math.max(0, target - current);
  const pct = target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0;
  const completed = goal.status === "completed" || current >= target;
  const Icon = goalIconFor(goal.icon);

  function handleComplete() {
    startTransition(async () => {
      try {
        await completeGoalAction(goal.id);
        toast.success(t("goals.goalCompleted"));
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("goals.completeError"),
        );
      }
    });
  }

  return (
    <Card
      className={`flex flex-col p-5 ${completed ? "border-primary/25 sage-glow" : ""}`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          <span
            className={`flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-lg)] ${
              completed
                ? "bg-primary/15 text-primary"
                : "bg-primary/10 text-primary"
            }`}
          >
            <Icon className="size-5" />
          </span>
          <div className="min-w-0">
            <h3 className="truncate text-[15px] font-semibold">{goal.name}</h3>
            {goal.target_date ? (
              <p className="text-text-muted flex items-center gap-1 text-xs">
                <CalendarClock className="size-3" />
                {format(new Date(goal.target_date), t("goals.dateFormat"), {
                  locale: DATE_LOCALES[locale],
                })}
              </p>
            ) : (
              <p className="text-text-dim text-xs">{t("goals.noTargetDate")}</p>
            )}
          </div>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              aria-label={t("goals.goalActions", { name: goal.name })}
              className="text-text-muted hover:text-foreground hover:bg-white/[0.06] -mr-1.5 -mt-1 flex size-10 min-h-11 min-w-11 shrink-0 items-center justify-center rounded-[var(--radius-md)] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring/40"
            >
              <MoreHorizontal className="size-4" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            <DropdownMenuItem onSelect={() => setContribOpen(true)}>
              <Plus />
              {t("goals.contribute")}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => setEditOpen(true)}>
              <Pencil />
              {t("common.edit")}
            </DropdownMenuItem>
            {!completed && (
              <DropdownMenuItem onSelect={handleComplete} disabled={pending}>
                <CheckCircle2 />
                {t("goals.markCompleted")}
              </DropdownMenuItem>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {/* Progreso */}
      <div className="mt-4 flex items-end justify-between gap-2">
        <Amount
          value={current}
          currency={currency}
          kind="balance"
          serif
          className="text-xl"
        />
        <span className="text-text-muted text-xs">
          {t("goals.ofTarget", { target: formatMoney(target, currency) })}
        </span>
      </div>

      <div className="mt-2.5 flex items-center gap-3">
        <Progress
          value={pct}
          indicatorClassName={completed ? "bg-income" : "bg-primary"}
          className="flex-1"
          aria-label={t("goals.progressAria", { pct, name: goal.name })}
        />
        <span className="text-foreground tnum w-10 shrink-0 text-right text-xs font-semibold">
          {pct}%
        </span>
      </div>

      <div className="mt-4 flex items-center justify-between gap-2">
        {completed ? (
          <Badge variant="income" className="gap-1">
            <Trophy className="size-3" />
            {t("goals.goalReached")}
          </Badge>
        ) : (
          <p className="text-text-muted text-xs">
            {t("goals.remainingPrefix")}
            <span className="text-foreground font-medium">
              {formatMoney(remaining, currency)}
            </span>
          </p>
        )}
        {!completed && (
          <Button size="sm" variant="secondary" onClick={() => setContribOpen(true)}>
            <Plus className="size-4" />
            {t("goals.contribute")}
          </Button>
        )}
      </div>

      {/* Diálogos controlados desde la card */}
      <ContributionDialog
        goalId={goal.id}
        goalName={goal.name}
        currency={currency}
        remaining={remaining}
        open={contribOpen}
        onOpenChange={setContribOpen}
      />
      <GoalDialog
        defaultCurrency={defaultCurrency}
        edit={{
          id: goal.id,
          name: goal.name,
          targetAmount: target,
          currency,
          targetDate: goal.target_date,
          icon: goal.icon,
        }}
        open={editOpen}
        onOpenChange={setEditOpen}
        hideTrigger
      />
    </Card>
  );
}
