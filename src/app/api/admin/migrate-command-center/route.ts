import { NextResponse } from "next/server";
import { turso } from "@/db/client";

export const runtime = "nodejs";

const MIGRATION_HASH =
  "e80c3735a10517268edeef4fef83d34060e2c48c8e3527ee2e0650ddfb50ed3c";
const MIGRATION_CREATED_AT = 1784220000000;

async function tableExists(name: string) {
  const result = await turso.execute({
    sql: "select name from sqlite_master where type = 'table' and name = ?",
    args: [name],
  });
  return result.rows.length > 0;
}

async function columnExists(table: string, column: string) {
  const result = await turso.execute(`pragma table_info(${table})`);
  return result.rows.some((row) => row.name === column);
}

async function exec(sql: string) {
  await turso.execute(sql);
}

export async function POST(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const applied: string[] = [];

  if (!(await columnExists("households", "weather_location"))) {
    await exec(
      "alter table `households` add `weather_location` text default 'Chicago, IL' not null",
    );
    applied.push("households.weather_location");
  }
  if (!(await columnExists("households", "weather_latitude"))) {
    await exec(
      "alter table `households` add `weather_latitude` text default '41.8781' not null",
    );
    applied.push("households.weather_latitude");
  }
  if (!(await columnExists("households", "weather_longitude"))) {
    await exec(
      "alter table `households` add `weather_longitude` text default '-87.6298' not null",
    );
    applied.push("households.weather_longitude");
  }

  await exec(`create table if not exists \`shopping_items\` (
    \`id\` text primary key not null,
    \`household_id\` text not null,
    \`title\` text not null,
    \`quantity\` text,
    \`category\` text default 'Other' not null,
    \`checked\` integer default 0 not null,
    \`checked_at\` integer,
    \`sort_order\` integer default 0 not null,
    \`created_at\` integer not null,
    \`updated_at\` integer not null,
    foreign key (\`household_id\`) references \`households\`(\`id\`) on update no action on delete cascade
  )`);
  await exec(
    "create index if not exists `shopping_items_household_idx` on `shopping_items` (`household_id`)",
  );
  await exec(
    "create index if not exists `shopping_items_checked_idx` on `shopping_items` (`household_id`,`checked`)",
  );

  await exec(`create table if not exists \`household_notes\` (
    \`id\` text primary key not null,
    \`household_id\` text not null,
    \`created_by_user_id\` text,
    \`title\` text not null,
    \`body\` text default '' not null,
    \`color\` text default '#f8e8bf' not null,
    \`pinned\` integer default 1 not null,
    \`created_at\` integer not null,
    \`updated_at\` integer not null,
    foreign key (\`household_id\`) references \`households\`(\`id\`) on update no action on delete cascade,
    foreign key (\`created_by_user_id\`) references \`users\`(\`id\`) on update no action on delete set null
  )`);
  await exec(
    "create index if not exists `household_notes_household_idx` on `household_notes` (`household_id`)",
  );
  await exec(
    "create index if not exists `household_notes_pinned_idx` on `household_notes` (`household_id`,`pinned`)",
  );

  await exec(`create table if not exists \`family_birthdays\` (
    \`id\` text primary key not null,
    \`household_id\` text not null,
    \`profile_id\` text,
    \`name\` text not null,
    \`birth_date\` text not null,
    \`notes\` text,
    \`gift_ideas\` text,
    \`notify_days_before\` integer default 7 not null,
    \`created_at\` integer not null,
    \`updated_at\` integer not null,
    foreign key (\`household_id\`) references \`households\`(\`id\`) on update no action on delete cascade,
    foreign key (\`profile_id\`) references \`profiles\`(\`id\`) on update no action on delete cascade
  )`);
  await exec(
    "create index if not exists `family_birthdays_household_idx` on `family_birthdays` (`household_id`)",
  );
  await exec(
    "create index if not exists `family_birthdays_profile_idx` on `family_birthdays` (`profile_id`)",
  );

  await exec(`create table if not exists \`school_subjects\` (
    \`id\` text primary key not null,
    \`household_id\` text not null,
    \`name\` text not null,
    \`color\` text default '#6689a3' not null,
    \`pack_items\` text default '' not null,
    \`sort_order\` integer default 0 not null,
    \`created_at\` integer not null,
    \`updated_at\` integer not null,
    foreign key (\`household_id\`) references \`households\`(\`id\`) on update no action on delete cascade
  )`);
  await exec(
    "create index if not exists `school_subjects_household_idx` on `school_subjects` (`household_id`)",
  );

  await exec(`create table if not exists \`school_periods\` (
    \`id\` text primary key not null,
    \`household_id\` text not null,
    \`label\` text not null,
    \`starts_at\` text default '08:00' not null,
    \`ends_at\` text default '08:45' not null,
    \`sort_order\` integer default 0 not null,
    \`created_at\` integer not null,
    \`updated_at\` integer not null,
    foreign key (\`household_id\`) references \`households\`(\`id\`) on update no action on delete cascade
  )`);
  await exec(
    "create index if not exists `school_periods_household_idx` on `school_periods` (`household_id`)",
  );

  await exec(`create table if not exists \`school_schedule_entries\` (
    \`id\` text primary key not null,
    \`household_id\` text not null,
    \`profile_id\` text,
    \`subject_id\` text not null,
    \`period_id\` text not null,
    \`weekday\` integer not null,
    \`room\` text,
    \`notes\` text,
    \`created_at\` integer not null,
    \`updated_at\` integer not null,
    foreign key (\`household_id\`) references \`households\`(\`id\`) on update no action on delete cascade,
    foreign key (\`profile_id\`) references \`profiles\`(\`id\`) on update no action on delete cascade,
    foreign key (\`subject_id\`) references \`school_subjects\`(\`id\`) on update no action on delete cascade,
    foreign key (\`period_id\`) references \`school_periods\`(\`id\`) on update no action on delete cascade
  )`);
  await exec(
    "create index if not exists `school_schedule_household_day_idx` on `school_schedule_entries` (`household_id`,`weekday`)",
  );
  await exec(
    "create unique index if not exists `school_schedule_slot_idx` on `school_schedule_entries` (`household_id`,`profile_id`,`period_id`,`weekday`)",
  );

  await exec(`create table if not exists \`notification_preferences\` (
    \`id\` text primary key not null,
    \`household_id\` text not null,
    \`user_id\` text not null,
    \`calendar_reminders\` integer default 1 not null,
    \`chore_digest\` integer default 1 not null,
    \`birthday_reminders\` integer default 1 not null,
    \`school_reminders\` integer default 1 not null,
    \`quiet_start\` text default '20:30' not null,
    \`quiet_end\` text default '07:00' not null,
    \`created_at\` integer not null,
    \`updated_at\` integer not null,
    foreign key (\`household_id\`) references \`households\`(\`id\`) on update no action on delete cascade,
    foreign key (\`user_id\`) references \`users\`(\`id\`) on update no action on delete cascade
  )`);
  await exec(
    "create unique index if not exists `notification_preferences_user_household_idx` on `notification_preferences` (`household_id`,`user_id`)",
  );

  await exec(`create table if not exists \`recycle_bin_items\` (
    \`id\` text primary key not null,
    \`household_id\` text not null,
    \`item_type\` text not null,
    \`item_id\` text not null,
    \`label\` text not null,
    \`snapshot\` text not null,
    \`deleted_at\` integer not null,
    \`restore_by\` integer,
    foreign key (\`household_id\`) references \`households\`(\`id\`) on update no action on delete cascade
  )`);
  await exec(
    "create index if not exists `recycle_bin_household_idx` on `recycle_bin_items` (`household_id`)",
  );
  await exec(
    "create index if not exists `recycle_bin_type_idx` on `recycle_bin_items` (`household_id`,`item_type`)",
  );

  if (await tableExists("__drizzle_migrations")) {
    const existing = await turso.execute({
      sql: "select hash from `__drizzle_migrations` where hash = ? limit 1",
      args: [MIGRATION_HASH],
    });
    if (!existing.rows[0]) {
      await turso.execute({
        sql: "insert into `__drizzle_migrations` (`hash`, `created_at`) values (?, ?)",
        args: [MIGRATION_HASH, MIGRATION_CREATED_AT],
      });
      applied.push("__drizzle_migrations.0016");
    }
  }

  return NextResponse.json({ ok: true, applied });
}
