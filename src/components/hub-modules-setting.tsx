"use client";

import { LayoutGrid } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import {
  saveHubModules,
  resetHubModules,
} from "@/app/(hub)/settings/hub-modules-actions";
import {
  FOOD_HUB_MODULES,
  HUB_MODULE_LABELS,
  type HubModuleId,
  type HubModules,
  SIDEBAR_HUB_MODULES,
} from "@/lib/hub-modules";

export function HubModulesSetting({
  initialModules,
}: {
  initialModules: HubModules;
}) {
  const router = useRouter();
  const [modules, setModules] = useState(initialModules);
  const [isPending, startTransition] = useTransition();

  function toggle(module: HubModuleId, enabled: boolean) {
    const next = { ...modules, [module]: enabled };
    setModules(next);
    startTransition(async () => {
      await saveHubModules(next);
      router.refresh();
    });
  }

  function handleReset() {
    startTransition(async () => {
      const next = await resetHubModules();
      setModules(next);
      router.refresh();
    });
  }

  return (
    <section className="hub-card p-6 max-md:p-4">
      <LayoutGrid className="text-[var(--sage)]" size={28} />
      <h2 className="font-display mt-4 text-2xl font-semibold">Hub sections</h2>
      <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
        Choose which optional modules appear in the sidebar and Food tabs.
        Today&apos;s dashboard stays the same — hidden items remain on Today.
      </p>

      <div className="mt-5 space-y-5">
        <ModuleGroup
          title="Sidebar"
          description="Optional shortcuts beside Calendar, Food, and Sleep."
          modules={SIDEBAR_HUB_MODULES}
          values={modules}
          disabled={isPending}
          onToggle={toggle}
        />
        <ModuleGroup
          title="Food tabs"
          description="Weekly meal plan is always included."
          modules={FOOD_HUB_MODULES}
          values={modules}
          disabled={isPending}
          onToggle={toggle}
        />
      </div>

      <button
        type="button"
        className="hub-button secondary mt-5"
        disabled={isPending}
        onClick={handleReset}
      >
        Reset to defaults
      </button>
    </section>
  );
}

function ModuleGroup({
  title,
  description,
  modules,
  values,
  disabled,
  onToggle,
}: {
  title: string;
  description: string;
  modules: HubModuleId[];
  values: HubModules;
  disabled: boolean;
  onToggle: (module: HubModuleId, enabled: boolean) => void;
}) {
  return (
    <div className="rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-4">
      <h3 className="font-display text-lg font-semibold">{title}</h3>
      <p className="mt-1 text-sm text-[var(--muted)]">{description}</p>
      <div className="mt-4 space-y-3">
        {modules.map((module) => (
          <label
            key={module}
            className="flex items-center justify-between gap-4 rounded-xl bg-[var(--tile-quiet)] px-4 py-3"
          >
            <span className="font-bold">{HUB_MODULE_LABELS[module]}</span>
            <input
              type="checkbox"
              className="h-5 w-5 accent-[var(--sage)]"
              checked={values[module]}
              disabled={disabled}
              onChange={(event) => onToggle(module, event.target.checked)}
            />
          </label>
        ))}
      </div>
    </div>
  );
}
