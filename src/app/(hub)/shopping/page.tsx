import { asc, eq } from "drizzle-orm";
import { Plus, Trash2 } from "lucide-react";
import {
  addShoppingItem,
  clearCheckedShoppingItems,
  deleteShoppingItem,
  toggleShoppingItem,
} from "@/app/actions";
import { CheckItem } from "@/components/check-item";
import { db } from "@/db/client";
import { shoppingItems } from "@/db/schema";
import { requireHousehold } from "@/lib/household";
import { groupedShoppingItems } from "@/lib/shopping";

export default async function ShoppingPage() {
  const household = await requireHousehold();
  const items = await db
    .select()
    .from(shoppingItems)
    .where(eq(shoppingItems.householdId, household.id))
    .orderBy(asc(shoppingItems.checked), asc(shoppingItems.category), asc(shoppingItems.createdAt));
  const unchecked = items.filter((item) => !item.checked);
  const checked = items.filter((item) => item.checked);
  const groups = groupedShoppingItems(unchecked);

  return (
    <div className="mx-auto max-w-5xl pb-10">
      <div className="flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Grocery run
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
            Shopping list
          </h1>
        </div>
        {checked.length > 0 && (
          <form action={clearCheckedShoppingItems}>
            <button className="hub-button secondary coral" type="submit">
              <Trash2 size={17} /> Clear checked
            </button>
          </form>
        )}
      </div>

      <form action={addShoppingItem} className="hub-card mt-6 grid grid-cols-[1fr_auto] gap-3 p-4 max-sm:grid-cols-1">
        <input
          name="title"
          className="hub-input"
          placeholder="Add milk, apples, 2 lb pasta..."
          required
        />
        <button className="hub-button px-5">
          <Plus size={18} /> Add
        </button>
      </form>

      <div className="mt-5 grid grid-cols-[1fr_320px] gap-5 max-lg:grid-cols-1">
        <section className="hub-card p-5">
          {groups.size ? (
            <div className="space-y-5">
              {Array.from(groups.entries()).map(([category, group]) => (
                <div key={category}>
                  <h2 className="mb-2 text-xs font-extrabold uppercase tracking-[0.16em] text-[var(--muted)]">
                    {category}
                  </h2>
                  <div className="space-y-2">
                    {group.map((item) => (
                      <div key={item.id} className="grid grid-cols-[1fr_auto] gap-2">
                        <CheckItem
                          label={item.title}
                          detail={item.quantity ?? undefined}
                          initialChecked={item.checked}
                          onToggle={toggleShoppingItem.bind(null, item.id)}
                        />
                        <form action={deleteShoppingItem.bind(null, item.id)}>
                          <button
                            className="flex h-14 w-12 items-center justify-center rounded-2xl text-[var(--muted)] hover:bg-[var(--tile-quiet)] hover:text-[var(--coral)]"
                            type="submit"
                            aria-label={`Delete ${item.title}`}
                          >
                            <Trash2 size={18} />
                          </button>
                        </form>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="rounded-2xl border border-dashed border-[var(--line)] p-8 text-center text-sm font-bold text-[var(--muted)]">
              Nothing on the list.
            </p>
          )}
        </section>

        <aside className="hub-card p-5">
          <h2 className="font-display text-2xl font-semibold">Checked off</h2>
          <div className="mt-4 space-y-2">
            {checked.length ? (
              checked.slice(0, 10).map((item) => (
                <CheckItem
                  key={item.id}
                  label={item.title}
                  detail={item.category}
                  initialChecked
                  onToggle={toggleShoppingItem.bind(null, item.id)}
                />
              ))
            ) : (
              <p className="text-sm font-semibold text-[var(--muted)]">
                Completed items land here until you clear them.
              </p>
            )}
          </div>
        </aside>
      </div>
    </div>
  );
}
