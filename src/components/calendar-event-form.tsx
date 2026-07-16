"use client";

import { useState } from "react";

type CalendarOption = {
  id: string;
  displayName: string;
  provider: "icloud" | "google";
};

function providerLabel(provider: CalendarOption["provider"]) {
  return provider === "google" ? "Google" : "Apple";
}

export function CalendarEventForm({
  action,
  calendars,
  timezone,
  submitLabel,
  eventId,
  defaultValues,
}: {
  action: (formData: FormData) => void | Promise<void>;
  calendars: CalendarOption[];
  timezone: string;
  submitLabel: string;
  eventId?: string;
  defaultValues: {
    title: string;
    calendarId: string;
    startsAt: string;
    endsAt: string;
    allDay: boolean;
    location: string;
    description: string;
  };
}) {
  const [allDay, setAllDay] = useState(defaultValues.allDay);
  const showProvider = new Set(calendars.map((calendar) => calendar.provider)).size > 1;

  return (
    <form action={action} className="space-y-2">
      {eventId && <input type="hidden" name="eventId" value={eventId} />}
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Title</span>
        <input
          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
          name="title"
          defaultValue={defaultValues.title}
          required
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Calendar</span>
        <select
          name="calendarId"
          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
          defaultValue={defaultValues.calendarId}
          required
        >
          {calendars.map((calendar) => (
            <option key={calendar.id} value={calendar.id}>
              {calendar.displayName}
              {showProvider ? ` · ${providerLabel(calendar.provider)}` : ""}
            </option>
          ))}
        </select>
      </label>
      <label className="flex items-center gap-2 text-xs font-bold">
        <input
          type="checkbox"
          name="allDay"
          checked={allDay}
          onChange={(event) => setAllDay(event.target.checked)}
          className="h-4 w-4 rounded border-[var(--line)]"
        />
        All-day event
      </label>
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Starts</span>
        <input
          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
          name="startsAt"
          type={allDay ? "date" : "datetime-local"}
          defaultValue={defaultValues.startsAt}
          required
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Ends</span>
        <input
          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
          name="endsAt"
          type={allDay ? "date" : "datetime-local"}
          defaultValue={defaultValues.endsAt}
          required
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Location</span>
        <input
          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
          name="location"
          defaultValue={defaultValues.location}
          placeholder="Optional"
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Notes</span>
        <textarea
          className="hub-input min-h-16 !rounded-lg !p-2 text-xs"
          name="description"
          defaultValue={defaultValues.description}
          placeholder="Optional"
        />
      </label>
      <button className="hub-button !min-h-9 w-full !py-1 text-xs">
        {submitLabel}
      </button>
      <p className="text-[10px] leading-4 text-[var(--muted)]">
        Times use your household timezone ({timezone.replaceAll("_", " ")}).
      </p>
    </form>
  );
}
