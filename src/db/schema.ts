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
  inviteCode: text("invite_code").notNull().unique(),
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
    role: text("role", { enum: ["owner", "parent"] })
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
    name: text("name").notNull(),
    color: text("color").notNull().default("#4f7c6d"),
    avatar: text("avatar").notNull().default("sparkles"),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (table) => [index("profiles_household_idx").on(table.householdId)],
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

export const calendarConnections = sqliteTable(
  "calendar_connections",
  {
    id: text("id").primaryKey(),
    householdId: text("household_id")
      .notNull()
      .references(() => households.id, { onDelete: "cascade" }),
    appleId: text("apple_id").notNull(),
    encryptedPassword: text("encrypted_password").notNull(),
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
    uniqueIndex("calendar_connections_household_idx").on(table.householdId),
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
