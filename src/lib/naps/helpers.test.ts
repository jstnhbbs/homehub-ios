import { describe, expect, it } from "vitest";
import {
  childWeekSleepStats,
  formatAverageSessionCount,
  formatChildDaySummary,
  formatChildTodaySleepSummary,
  formatDashboardSleepSecondary,
  formatSleepDuration,
  getChildDashboardSleepStatus,
  napDurationMinutes,
} from "./helpers";

describe("napDurationMinutes", () => {
  it("counts minutes for a finished nap", () => {
    const startedAt = new Date("2026-07-28T13:00:00.000Z");
    const endedAt = new Date("2026-07-28T13:47:00.000Z");
    expect(napDurationMinutes(startedAt, endedAt)).toBe(47);
  });

  it("uses now for an active nap", () => {
    const startedAt = new Date("2026-07-28T13:00:00.000Z");
    const now = new Date("2026-07-28T13:30:00.000Z");
    expect(napDurationMinutes(startedAt, null, now)).toBe(30);
  });
});

describe("formatChildDaySummary", () => {
  it("returns no sleep when empty", () => {
    expect(formatChildDaySummary(0, 0, 0)).toBe("No sleep logged");
  });

  it("summarizes naps, nights, and duration", () => {
    expect(formatChildDaySummary(2, 1, 95)).toBe(
      "2 naps · 1 night · 1h 35m total",
    );
  });
});

describe("formatAverageSessionCount", () => {
  it("formats whole numbers without decimals", () => {
    expect(formatAverageSessionCount(2)).toBe("2");
  });

  it("formats fractional averages to one decimal", () => {
    expect(formatAverageSessionCount(1.666666)).toBe("1.7");
  });
});

describe("getChildDashboardSleepStatus", () => {
  const logs = [
    {
      id: "nap-1",
      profileId: "child-1",
      kind: "nap" as const,
      localDate: "2026-07-28",
      startedAt: new Date("2026-07-28T13:00:00.000Z"),
      endedAt: new Date("2026-07-28T14:00:00.000Z"),
    },
    {
      id: "night-1",
      profileId: "child-2",
      kind: "night" as const,
      localDate: "2026-07-28",
      startedAt: new Date("2026-07-28T01:00:00.000Z"),
      endedAt: null,
    },
  ];

  it("detects an active bedtime", () => {
    const status = getChildDashboardSleepStatus(
      logs,
      "child-2",
      "2026-07-28",
      "UTC",
      new Date("2026-07-28T02:30:00.000Z"),
    );
    expect(status.state).toBe("in_bed");
    expect(status.activeLogId).toBe("night-1");
    expect(formatDashboardSleepSecondary(status)).toBe("Night in progress");
  });

  it("shows awake time and today totals when up", () => {
    const status = getChildDashboardSleepStatus(
      logs,
      "child-1",
      "2026-07-28",
      "UTC",
      new Date("2026-07-28T16:00:00.000Z"),
    );
    expect(status.state).toBe("awake");
    expect(status.durationMinutes).toBe(120);
    expect(formatDashboardSleepSecondary(status)).toBe("1 nap · 1h total");
  });
});

describe("formatChildTodaySleepSummary", () => {
  it("summarizes completed sleep and awake time", () => {
    const now = new Date("2026-07-28T16:00:00.000Z");
    const summary = formatChildTodaySleepSummary(
      [
        {
          kind: "nap",
          startedAt: new Date("2026-07-28T13:00:00.000Z"),
          endedAt: new Date("2026-07-28T14:00:00.000Z"),
        },
        {
          kind: "nap",
          startedAt: new Date("2026-07-28T14:30:00.000Z"),
          endedAt: new Date("2026-07-28T15:00:00.000Z"),
        },
      ],
      now,
    );
    expect(summary).toBe("2 naps · 1h 30m total · Awake 1h");
  });
});

describe("childWeekSleepStats", () => {
  it("computes weekly totals and averages through today", () => {
    const logs = [
      {
        profileId: "child-1",
        kind: "nap" as const,
        localDate: "2026-07-28",
        startedAt: new Date("2026-07-28T13:00:00.000Z"),
        endedAt: new Date("2026-07-28T14:00:00.000Z"),
      },
      {
        profileId: "child-1",
        kind: "nap" as const,
        localDate: "2026-07-28",
        startedAt: new Date("2026-07-28T15:00:00.000Z"),
        endedAt: new Date("2026-07-28T15:30:00.000Z"),
      },
      {
        profileId: "child-1",
        kind: "night" as const,
        localDate: "2026-07-27",
        startedAt: new Date("2026-07-27T13:00:00.000Z"),
        endedAt: new Date("2026-07-27T14:30:00.000Z"),
      },
    ];

    const stats = childWeekSleepStats(
      logs,
      "child-1",
      ["2026-07-27", "2026-07-28", "2026-07-29"],
      "2026-07-28",
      "UTC",
    );

    expect(stats.totalNaps).toBe(2);
    expect(stats.totalNights).toBe(1);
    expect(stats.totalMinutes).toBe(180);
    expect(stats.elapsedDays).toBe(2);
    expect(stats.avgSessionsPerDay).toBe(1.5);
    expect(stats.avgMinutesPerDay).toBe(90);
  });
});
