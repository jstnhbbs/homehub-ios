import { desc, eq } from "drizzle-orm";
import { Plus, Trash2 } from "lucide-react";
import { addHouseholdNote, deleteHouseholdNote } from "@/app/actions";
import { db } from "@/db/client";
import { householdNotes } from "@/db/schema";
import { requireHousehold } from "@/lib/household";

const noteColors = ["#f8e8bf", "#dce9df", "#dce7ed", "#f5d9d0"] as const;

export default async function NotesPage() {
  const household = await requireHousehold();
  const notes = await db
    .select()
    .from(householdNotes)
    .where(eq(householdNotes.householdId, household.id))
    .orderBy(desc(householdNotes.pinned), desc(householdNotes.updatedAt));

  return (
    <div className="mx-auto max-w-6xl pb-10">
      <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
        Fridge door
      </p>
      <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
        Household notes
      </h1>

      <form action={addHouseholdNote} className="hub-card mt-6 grid gap-3 p-5">
        <div className="grid grid-cols-[1fr_auto] gap-3 max-sm:grid-cols-1">
          <input name="title" className="hub-input" placeholder="Note title" required />
          <button className="hub-button px-5">
            <Plus size={18} /> Add note
          </button>
        </div>
        <textarea
          name="body"
          className="hub-input min-h-24 resize-y"
          placeholder="Write the thing everyone needs to remember..."
        />
        <div className="flex gap-2">
          {noteColors.map((color, index) => (
            <label key={color} className="cursor-pointer">
              <input
                type="radio"
                name="color"
                value={color}
                defaultChecked={index === 0}
                className="peer sr-only"
              />
              <span
                className="block h-9 w-9 rounded-full border-2 border-transparent peer-checked:border-[var(--foreground)]"
                style={{ background: color }}
              />
            </label>
          ))}
        </div>
      </form>

      <div className="mt-5 grid grid-cols-3 gap-4 max-lg:grid-cols-2 max-sm:grid-cols-1">
        {notes.map((note) => (
          <article
            key={note.id}
            className="min-h-48 rounded-[8px] border border-[var(--line)] p-5 shadow-sm"
            style={{ background: note.color }}
          >
            <div className="flex items-start justify-between gap-3 text-[#21342f]">
              <h2 className="font-display text-2xl font-semibold">{note.title}</h2>
              <form action={deleteHouseholdNote.bind(null, note.id)}>
                <button
                  type="submit"
                  className="rounded-full p-2 text-[#5f6964] hover:bg-black/10"
                  aria-label={`Delete ${note.title}`}
                >
                  <Trash2 size={17} />
                </button>
              </form>
            </div>
            {note.body && (
              <p className="mt-4 whitespace-pre-wrap text-sm font-semibold leading-6 text-[#3f504b]">
                {note.body}
              </p>
            )}
          </article>
        ))}
      </div>
    </div>
  );
}
