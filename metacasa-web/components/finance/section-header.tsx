export function SectionHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="mb-3 flex items-end justify-between gap-3">
      <div>
        <h2 className="text-[15px] font-semibold text-foreground">{title}</h2>
        {subtitle && <p className="text-text-muted text-xs">{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}
