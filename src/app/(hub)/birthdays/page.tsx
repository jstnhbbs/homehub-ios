import { asc, eq } from "drizzle-orm";
import { Gift, Plus, Trash2 } from "lucide-react";
import { addFamilyBirthday, deleteFamilyBirthday } from "@/app/actions";
import { db } from "@/db/client";
import { familyBirthdays, profiles } from "@/db/schema";
import { upcomingFamilyBirthdays } from "@/lib/family-birthdays";
import { requireHousehold } from "@/lib/household";
import { localDateIn } from "@/lib/dates";

export default async function BirthdaysPage() {
  const household = await requireHousehold();
  const today = localDateIn(household.timezone);
  const [birthdayRows, profileRows] = await Promise.all([
    db
      .select()
      .from(familyBirthdays)
      .where(eq(familyBirthdays.householdId, household.id))
      .orderBy(asc(familyBirthdays.name)),
    db
      .select()
      .from(profiles)
      .where(eq(profiles.householdId, household.id))
      .orderBy(asc(profiles.sortOrder)),
  ]);
  const profileBirthdays = profileRows
    .filter((profile) => profile.birthday)
    .map((profile) => ({
      id: `profile-${profile.id}`,
      name: profile.name,
      birthDate: profile.birthday ?? "",
      color: profile.color,
      notes: "Family profile",
    }));
  const upcoming = upcomingFamilyBirthdays(
    [
      ...profileBirthdays,
      ...birthdayRows.map((birthday) => ({
        id: birthday.id,
        name: birthday.name,
        birthDate: birthday.birthDate,
        notes: birthday.notes,
        giftIdeas: birthday.giftIdeas,
        notifyDaysBefore: birthday.notifyDaysBefore,
      })),
    ],
    today,
    120,
  );

  return (
    <div className="mx-auto max-w-6xl pb-10">
      <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
        Celebrate people
      </p>
      <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
        Birthdays
      </h1>

      <div className="mt-6 grid grid-cols-[360px_1fr] gap-5 max-lg:grid-cols-1">
        <form action={addFamilyBirthday} className="hub-card grid gap-3 p-5">
          <h2 className="font-display text-2xl font-semibold">Add birthday</h2>
          <input name="name" className="hub-input" placeholder="Name" required />
          <input name="birthDate" className="hub-input" type="date" required />
          <select name="profileId" className="hub-input" defaultValue="">
            <option value="">Not linked to a profile</option>
            {profileRows.map((profile) => (
              <option key={profile.id} value={profile.id}>
                {profile.name}
              </option>
            ))}
          </select>
          <textarea name="giftIdeas" className="hub-input min-h-20 resize-y" placeholder="Gift ideas" />
          <textarea name="notes" className="hub-input min-h-20 resize-y" placeholder="Notes" />
          <label className="text-xs font-bold">
            Remind days before
            <input
              name="notifyDaysBefore"
              className="hub-input mt-1"
              type="number"
              min="0"
              max="60"
              defaultValue="7"
            />
          </label>
          <button className="hub-button">
            <Plus size={18} /> Add birthday
          </button>
        </form>

        <section className="hub-card p-5">
          <h2 className="font-display text-2xl font-semibold">Next up</h2>
          <div className="mt-4 grid grid-cols-2 gap-3 max-sm:grid-cols-1">
            {upcoming.map((birthday) => (
              <div key={birthday.id} className="rounded-2xl bg-[var(--tile)] p-4">
                <div className="flex items-start gap-3">
                  <Gift className="mt-1 shrink-0 text-[var(--coral)]" size={20} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-bold">{birthday.name}</p>
                    <p className="text-sm font-semibold text-[var(--muted)]">
                      {birthday.localDate} · {birthday.daysUntil === 0 ? "Today" : `${birthday.daysUntil} days`}
                    </p>
                    {birthday.giftIdeas && (
                      <p className="mt-2 line-clamp-2 text-sm text-[var(--muted)]">
                        {birthday.giftIdeas}
                      </p>
                    )}
                  </div>
                  {!birthday.id.startsWith("profile-") && (
                    <form action={deleteFamilyBirthday.bind(null, birthday.id)}>
                      <button type="submit" aria-label={`Delete ${birthday.name}`}>
                        <Trash2 size={17} className="text-[var(--muted)]" />
                      </button>
                    </form>
                  )}
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
