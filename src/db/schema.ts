import { randomUUID } from "node:crypto";
import { relations } from "drizzle-orm";
import {
  index,
  integer,
  primaryKey,
  sqliteTable,
  text,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";

const timestamps = {
  createdAt: integer("created_at", { mode: "timestamp" })
    .$defaultFn(() => new Date())
    .notNull(),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .$defaultFn(() => new Date())
    .$onUpdate(() => new Date())
    .notNull(),
};

export const users = sqliteTable("users", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  emailVerified: integer("email_verified", { mode: "boolean" })
    .default(false)
    .notNull(),
  image: text("image"),
  hubModules: text("hub_modules").notNull().default(""),
  ...timestamps,
});

export const sessions = sqliteTable(
  "sessions",
  {
    id: text("id").primaryKey(),
    expiresAt: integer("expires_at", { mode: "timestamp" }).notNull(),
    token: text("token").notNull().unique(),
    ipAddress: text("ip_address"),
    userAgent: text("user_agent"),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    ...timestamps,
  },
  (table) => [index("sessions_user_idx").on(table.userId)],
);

export const accounts = sqliteTable(
  "accounts",
  {
    id: text("id").primaryKey(),
    accountId: text("account_id").notNull(),
    providerId: text("provider_id").notNull(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    accessToken: text("access_token"),
    refreshToken: text("refresh_token"),
    idToken: text("id_token"),
    accessTokenExpiresAt: integer("access_token_expires_at", {
      mode: "timestamp",
    }),
    refreshTokenExpiresAt: integer("refresh_token_expires_at", {
      mode: "timestamp",
    }),
    scope: text("scope"),
    password: text("password"),
    ...timestamps,
  },
  (table) => [index("accounts_user_idx").on(table.userId)],
);

export const verifications = sqliteTable(
  "verifications",
  {
    id: text("id").primaryKey(),
    identifier: text("identifier").notNull(),
    value: text("value").notNull(),
    expiresAt: integer("expires_at", { mode: "timestamp" }).notNull(),
    ...timestamps,
  },
  (table) => [index("verifications_identifier_idx").on(table.identifier)],
);

export const households = sqliteTable("households", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  timezone: text("timezone").notNull().default("America/Chicago"),
  calendarSyncIntervalMinutes: integer("calendar_sync_interval_minutes")
    .notNull()
    .default(15),
  weekStartsOn: integer("week_starts_on").notNull().default(1),
  inviteCode: text("invite_code").notNull().unique(),
  guestInviteCode: text("guest_invite_code").notNull().unique(),
  snackOptions: text("snack_options").notNull().default(""),
  weatherLocation: text("weather_location").notNull().default("Chicago, IL"),
  weatherLatitude: text("weather_latitude").notNull().default("41.8781"),
  weatherLongitude: text("weather_longitude").notNull().default("-87.6298"),
  ...timestamps,
});

export const householdMembers = sqliteTable(
  "household_members",
  {
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    role: text("role", { enum: ["owner", "parent", "guest"] })
      .notNull()
      .default("parent"),
    joinedAt: integer("joined_at", { mode: "timestamp" })
      .$defaultFn(() => new Date())
      .notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.householdId, table.userId] }),
    index("household_members_user_idx").on(table.userId),
  ],
);

export const profiles = sqliteTable(
  "profiles",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    userId: text("user_id").references(() => users.id, {
      onDelete: "set null",
    }),
    profileType: text("profile_type", { enum: ["adult", "child"] })
      .notNull()
      .default("child"),
    name: text("name").notNull(),
    color: text("color").notNull().default("#4f7c6d"),
    avatar: text("avatar").notNull().default("sparkles"),
    birthday: text("birthday"),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (table) => [
    index("profiles_household_idx").on(table.householdId),
    uniqueIndex("profiles_household_user_idx").on(
      table.householdId,
      table.userId,
    ),
  ],
);

export const routines = sqliteTable(
  "routines",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    profileId: text("profile_id").references(() => profiles.id, {
      onDelete: "cascade",
    }),
    name: text("name").notNull(),
    period: text("period", {
      enum: ["morning", "afternoon", "evening"],
    }).notNull(),
    days: text("days").notNull().default("0,1,2,3,4,5,6"),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (table) => [index("routines_household_idx").on(table.householdId)],
);

export const routineSteps = sqliteTable(
  "routine_steps",
  {
    id: text("id").primaryKey(),
    routineId: text("routine_id")
      .notNull()
      .references(() => routines.id, { onDelete: "cascade" }),
    label: text("label").notNull(),
    sortOrder: integer("sort_order").notNull().default(0),
  },
  (table) => [index("routine_steps_routine_idx").on(table.routineId)],
);

export const routineCompletions = sqliteTable(
  "routine_completions",
  {
    stepId: text("step_id")
      .notNull()
      .references(() => routineSteps.id, { onDelete: "cascade" }),
    localDate: text("local_date").notNull(),
    completedAt: integer("completed_at", { mode: "timestamp" })
      .$defaultFn(() => new Date())
      .notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.stepId, table.localDate] }),
    index("routine_completions_date_idx").on(table.localDate),
  ],
);

export const chores = sqliteTable(
  "chores",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    profileId: text("profile_id").references(() => profiles.id, {
      onDelete: "set null",
    }),
    title: text("title").notNull(),
    cadence: text("cadence", { enum: ["daily", "weekly"] })
      .notNull()
      .default("daily"),
    days: text("days").notNull().default("0,1,2,3,4,5,6"),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (table) => [index("chores_household_idx").on(table.householdId)],
);

export const choreCompletions = sqliteTable(
  "chore_completions",
  {
    choreId: text("chore_id")
      .notNull()
      .references(() => chores.id, { onDelete: "cascade" }),
    periodKey: text("period_key").notNull(),
    completedAt: integer("completed_at", { mode: "timestamp" })
      .$defaultFn(() => new Date())
      .notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.choreId, table.periodKey] }),
    index("chore_completions_period_idx").on(table.periodKey),
  ],
);

export const snackCompletions = sqliteTable(
  "snack_completions",
  {
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    localDate: text("local_date").notNull(),
    snackLabel: text("snack_label").notNull(),
    completedAt: integer("completed_at", { mode: "timestamp" })
      .$defaultFn(() => new Date())
      .notNull(),
  },
  (table) => [
    primaryKey({
      columns: [table.householdId, table.localDate, table.snackLabel],
    }),
    index("snack_completions_date_idx").on(table.localDate),
  ],
);

export const sleepKinds = ["nap", "night"] as const;
export type SleepKind = (typeof sleepKinds)[number];

export const napLogs = sqliteTable(
  "nap_logs",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    profileId: text("profile_id")
      .notNull()
      .references(() => profiles.id, { onDelete: "cascade" }),
    kind: text("kind").$type<SleepKind>().notNull().default("nap"),
    localDate: text("local_date").notNull(),
    startedAt: integer("started_at", { mode: "timestamp" }).notNull(),
    endedAt: integer("ended_at", { mode: "timestamp" }),
    notes: text("notes"),
    ...timestamps,
  },
  (table) => [
    index("nap_logs_household_date_idx").on(table.householdId, table.localDate),
    index("nap_logs_profile_idx").on(table.profileId),
  ],
);

export const recipes = sqliteTable(
  "recipes",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    description: text("description"),
    servings: text("servings"),
    prepTime: text("prep_time"),
    cookTime: text("cook_time"),
    totalTime: text("total_time"),
    ingredients: text("ingredients").notNull().default("[]"),
    directions: text("directions").notNull().default("[]"),
    nutrition: text("nutrition"),
    sourceUrl: text("source_url"),
    imageUrl: text("image_url"),
    notes: text("notes"),
    ...timestamps,
  },
  (table) => [index("recipes_household_idx").on(table.householdId)],
);

export const meals = sqliteTable(
  "meals",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    localDate: text("local_date").notNull(),
    slot: text("slot", {
      enum: ["breakfast", "lunch", "dinner", "snack"],
    }).notNull(),
    title: text("title").notNull(),
    recipeId: text("recipe_id").references(() => recipes.id, {
      onDelete: "set null",
    }),
    notes: text("notes"),
    ...timestamps,
  },
  (table) => [
    uniqueIndex("meals_household_date_slot_idx").on(
      table.householdId,
      table.localDate,
      table.slot,
    ),
  ],
);

export const shoppingItems = sqliteTable(
  "shopping_items",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    quantity: text("quantity"),
    category: text("category").notNull().default("Other"),
    checked: integer("checked", { mode: "boolean" }).notNull().default(false),
    checkedAt: integer("checked_at", { mode: "timestamp" }),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (table) => [
    index("shopping_items_household_idx").on(table.householdId),
    index("shopping_items_checked_idx").on(table.householdId, table.checked),
  ],
);

export const householdNotes = sqliteTable(
  "household_notes",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    createdByUserId: text("created_by_user_id").references(() => users.id, {
      onDelete: "set null",
    }),
    title: text("title").notNull(),
    body: text("body").notNull().default(""),
    color: text("color").notNull().default("#f8e8bf"),
    pinned: integer("pinned", { mode: "boolean" }).notNull().default(true),
    ...timestamps,
  },
  (table) => [
    index("household_notes_household_idx").on(table.householdId),
    index("household_notes_pinned_idx").on(table.householdId, table.pinned),
  ],
);

export const familyBirthdays = sqliteTable(
  "family_birthdays",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    profileId: text("profile_id").references(() => profiles.id, {
      onDelete: "cascade",
    }),
    name: text("name").notNull(),
    birthDate: text("birth_date").notNull(),
    notes: text("notes"),
    giftIdeas: text("gift_ideas"),
    notifyDaysBefore: integer("notify_days_before").notNull().default(7),
    ...timestamps,
  },
  (table) => [
    index("family_birthdays_household_idx").on(table.householdId),
    index("family_birthdays_profile_idx").on(table.profileId),
  ],
);

export const schoolSubjects = sqliteTable(
  "school_subjects",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    color: text("color").notNull().default("#6689a3"),
    packItems: text("pack_items").notNull().default(""),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (table) => [index("school_subjects_household_idx").on(table.householdId)],
);

export const schoolPeriods = sqliteTable(
  "school_periods",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    label: text("label").notNull(),
    startsAt: text("starts_at").notNull().default("08:00"),
    endsAt: text("ends_at").notNull().default("08:45"),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (table) => [index("school_periods_household_idx").on(table.householdId)],
);

export const schoolScheduleEntries = sqliteTable(
  "school_schedule_entries",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    profileId: text("profile_id").references(() => profiles.id, {
      onDelete: "cascade",
    }),
    subjectId: text("subject_id")
      .notNull()
      .references(() => schoolSubjects.id, { onDelete: "cascade" }),
    periodId: text("period_id")
      .notNull()
      .references(() => schoolPeriods.id, { onDelete: "cascade" }),
    weekday: integer("weekday").notNull(),
    room: text("room"),
    notes: text("notes"),
    ...timestamps,
  },
  (table) => [
    index("school_schedule_household_day_idx").on(
      table.householdId,
      table.weekday,
    ),
    uniqueIndex("school_schedule_slot_idx").on(
      table.householdId,
      table.profileId,
      table.periodId,
      table.weekday,
    ),
  ],
);

export const notificationPreferences = sqliteTable(
  "notification_preferences",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    calendarReminders: integer("calendar_reminders", { mode: "boolean" })
      .notNull()
      .default(true),
    choreDigest: integer("chore_digest", { mode: "boolean" })
      .notNull()
      .default(true),
    birthdayReminders: integer("birthday_reminders", { mode: "boolean" })
      .notNull()
      .default(true),
    schoolReminders: integer("school_reminders", { mode: "boolean" })
      .notNull()
      .default(true),
    quietStart: text("quiet_start").notNull().default("20:30"),
    quietEnd: text("quiet_end").notNull().default("07:00"),
    ...timestamps,
  },
  (table) => [
    uniqueIndex("notification_preferences_user_household_idx").on(
      table.householdId,
      table.userId,
    ),
  ],
);

export const recycleBinItems = sqliteTable(
  "recycle_bin_items",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    itemType: text("item_type").notNull(),
    itemId: text("item_id").notNull(),
    label: text("label").notNull(),
    snapshot: text("snapshot").notNull(),
    deletedAt: integer("deleted_at", { mode: "timestamp" })
      .$defaultFn(() => new Date())
      .notNull(),
    restoreBy: integer("restore_by", { mode: "timestamp" }),
  },
  (table) => [
    index("recycle_bin_household_idx").on(table.householdId),
    index("recycle_bin_type_idx").on(table.householdId, table.itemType),
  ],
);

export const calendarConnections = sqliteTable(
  "calendar_connections",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    provider: text("provider", { enum: ["icloud", "google"] })
      .notNull()
      .default("icloud"),
    accountEmail: text("account_email").notNull(),
    appleId: text("apple_id"),
    encryptedPassword: text("encrypted_password"),
    encryptedRefreshToken: text("encrypted_refresh_token"),
    encryptedAccessToken: text("encrypted_access_token"),
    accessTokenExpiresAt: integer("access_token_expires_at", {
      mode: "timestamp",
    }),
    status: text("status", {
      enum: ["connected", "syncing", "error"],
    })
      .notNull()
      .default("connected"),
    errorMessage: text("error_message"),
    lastSyncedAt: integer("last_synced_at", { mode: "timestamp" }),
    syncLockedAt: integer("sync_locked_at", { mode: "timestamp" }),
    ...timestamps,
  },
  (table) => [
    uniqueIndex("calendar_connections_household_provider_idx").on(
      table.householdId,
      table.provider,
    ),
  ],
);

export const calendars = sqliteTable(
  "calendars",
  {
    id: text("id").primaryKey(),
    connectionId: text("connection_id")
      .notNull()
      .references(() => calendarConnections.id, { onDelete: "cascade" }),
    url: text("url").notNull(),
    displayName: text("display_name").notNull(),
    color: text("color").notNull().default("#5b7cfa"),
    enabled: integer("enabled", { mode: "boolean" }).notNull().default(true),
    syncToken: text("sync_token"),
    ctag: text("ctag"),
  },
  (table) => [uniqueIndex("calendars_connection_url_idx").on(table.connectionId, table.url)],
);

export const calendarEvents = sqliteTable(
  "calendar_events",
  {
    id: text("id").primaryKey(),
    calendarId: text("calendar_id")
      .notNull()
      .references(() => calendars.id, { onDelete: "cascade" }),
    href: text("href").notNull(),
    etag: text("etag"),
    uid: text("uid").notNull(),
    title: text("title").notNull(),
    description: text("description"),
    location: text("location"),
    startsAt: integer("starts_at", { mode: "timestamp" }).notNull(),
    endsAt: integer("ends_at", { mode: "timestamp" }).notNull(),
    allDay: integer("all_day", { mode: "boolean" }).notNull().default(false),
    recurrenceRule: text("recurrence_rule"),
    rawIcal: text("raw_ical").notNull(),
    ...timestamps,
  },
  (table) => [
    uniqueIndex("calendar_events_href_idx").on(table.calendarId, table.href),
    index("calendar_events_range_idx").on(table.startsAt, table.endsAt),
  ],
);

export const rateLimits = sqliteTable("rate_limits", {
  id: text("id")
    .$defaultFn(() => randomUUID())
    .primaryKey(),
  key: text("key").notNull().unique(),
  count: integer("count").notNull().default(1),
  lastRequest: integer("last_request")
    .$defaultFn(() => Date.now())
    .notNull(),
});

export const usersRelations = relations(users, ({ many }) => ({
  sessions: many(sessions),
  accounts: many(accounts),
  memberships: many(householdMembers),
}));

export const householdsRelations = relations(households, ({ many }) => ({
  members: many(householdMembers),
  profiles: many(profiles),
}));

export const householdMembersRelations = relations(
  householdMembers,
  ({ one }) => ({
    user: one(users, {
      fields: [householdMembers.userId],
      references: [users.id],
    }),
    household: one(households, {
      fields: [householdMembers.householdId],
      references: [households.id],
    }),
  }),
);
