import { desc, eq } from "drizzle-orm";
import { RotateCcw } from "lucide-react";
import { restoreRecycleBinItem } from "@/app/actions";
import { db } from "@/db/client";
import { recycleBinItems } from "@/db/schema";
import { requireHousehold } from "@/lib/household";

export default async function RecycleBinPage() {
  const household = await requireHousehold();
  const items = await db
    .select()
    .from(recycleBinItems)
    .where(eq(recycleBinItems.householdId, household.id))
    .orderBy(desc(recycleBinItems.deletedAt));

  return (
    <div className="mx-auto max-w-4xl pb-10">
      <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
        Undo lane
      </p>
      <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
        Recycle bin
      </h1>
      <section className="hub-card mt-6 p-5">
        <div className="space-y-3">
          {items.length ? (
            items.map((item) => (
              <div key={item.id} className="flex items-center justify-between gap-4 rounded-2xl bg-[var(--tile)] p-4">
                <div className="min-w-0">
                  <p className="truncate font-bold">{item.label}</p>
                  <p className="text-sm font-semibold text-[var(--muted)]">
                    {item.itemType.replaceAll("_", " ")} · deleted {item.deletedAt.toLocaleDateString()}
                  </p>
                </div>
                <form action={restoreRecycleBinItem.bind(null, item.id)}>
                  <button className="hub-button secondary" type="submit">
                    <RotateCcw size={17} /> Restore
                  </button>
                </form>
              </div>
            ))
          ) : (
            <p className="rounded-2xl border border-dashed border-[var(--line)] p-8 text-center text-sm font-bold text-[var(--muted)]">
              Deleted shopping items, notes, and birthdays will appear here.
            </p>
          )}
        </div>
      </section>
    </div>
  );
}
