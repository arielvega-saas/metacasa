// MetaCasa — componentes de skeleton loaders.
// Extraído de App.jsx en Fase 2.

export function SkeletonCard({ className = "" }) {
  return <div className={`bg-zinc-900/60 rounded-3xl animate-pulse ${className}`} />;
}

export function LoadingSkeleton() {
  return (
    <div className="max-w-md mx-auto px-6 pt-6 space-y-6">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <SkeletonCard className="w-10 h-10 rounded-xl" />
          <div className="space-y-2">
            <SkeletonCard className="w-24 h-4" />
            <SkeletonCard className="w-16 h-2.5" />
          </div>
        </div>
        <div className="flex gap-2">
          <SkeletonCard className="w-11 h-11 rounded-2xl" />
          <SkeletonCard className="w-11 h-11 rounded-2xl" />
        </div>
      </div>
      <SkeletonCard className="h-52 rounded-[2.5rem]" />
      <SkeletonCard className="h-72 rounded-[2.5rem]" />
    </div>
  );
}
