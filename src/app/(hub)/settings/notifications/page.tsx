import { eq, and } from "drizzle-orm";
import { Bell, Save } from "lucide-react";
import { saveNotificationPreferences } from "@/app/actions";
import { db } from "@/db/client";
import { notificationPreferences } from "@/db/schema";
import { requireHousehold, requireUser } from "@/lib/household";

export default async function NotificationSettingsPage() {
  const household = await requireHousehold();
  const user = await requireUser();
  const rows = await db
    .select()
    .from(notificationPreferences)
    .where(
      and(
        eq(notificationPreferences.householdId, household.id),
        eq(notificationPreferences.userId, user.id),
      ),
    )
    .limit(1);
  const prefs = rows[0];

  return (
    <div className="mx-auto max-w-3xl pb-10">
      <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
        Heads up
      </p>
      <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
        Notification reminders
      </h1>
      <form action={saveNotificationPreferences} className="hub-card mt-6 grid gap-5 p-6">
        <Bell className="text-[var(--sage)]" size={28} />
        {[
          ["calendarReminders", "Calendar reminders", prefs?.calendarReminders ?? true],
          ["choreDigest", "Chore digest", prefs?.choreDigest ?? true],
          ["birthdayReminders", "Birthday reminders", prefs?.birthdayReminders ?? true],
          ["schoolReminders", "School pack reminders", prefs?.schoolReminders ?? true],
        ].map(([name, label, checked]) => (
          <label key={String(name)} className="flex items-center justify-between gap-4 rounded-2xl bg-[var(--tile)] p-4">
            <span className="font-bold">{label}</span>
            <input
              name={String(name)}
              type="checkbox"
              defaultChecked={Boolean(checked)}
              className="h-5 w-5 accent-[var(--sage)]"
            />
          </label>
        ))}
        <div className="grid grid-cols-2 gap-3 max-sm:grid-cols-1">
          <label className="text-xs font-bold">
            Quiet start
            <input name="quietStart" type="time" className="hub-input mt-1" defaultValue={prefs?.quietStart ?? "20:30"} />
          </label>
          <label className="text-xs font-bold">
            Quiet end
            <input name="quietEnd" type="time" className="hub-input mt-1" defaultValue={prefs?.quietEnd ?? "07:00"} />
          </label>
        </div>
        <button className="hub-button w-fit">
          <Save size={18} /> Save reminders
        </button>
      </form>
    </div>
  );
}
