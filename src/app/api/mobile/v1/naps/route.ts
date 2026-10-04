import { z } from "zod";
import {
  type NapLogRecord,
  createManualNap,
  createNightSleep,
  endNap,
  endNapForProfile,
  fetchNapPageData,
  serializeNap,
  startNap,
  startNightSleep,
} from "@/lib/naps/store";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
} from "@/lib/mobile/http";

const isoDate = z.string().datetime();

/**
 * Answers a write with the entry it created or changed, so the app can show it straight away
 * instead of fetching the whole page again. `nap` is extra: older apps only read `ok` and `id`.
 */
function changed(nap: NapLogRecord) {
  return mobileJson({ ok: true, id: nap.id, nap: serializeNap(nap) });
}

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const { localDate, weekDates, childProfiles, naps, weekLogs } =
      await fetchNapPageData(household);
    return mobileJson({
      localDate,
      weekDates,
      childProfiles,
      naps: naps.map(serializeNap),
      weekLogs: weekLogs.map(serializeNap),
    });
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const input = z
      .discriminatedUnion("action", [
        z.object({
          action: z.literal("start"),
          profileId: z.string().uuid(),
        }),
        z.object({
          action: z.literal("startNight"),
          profileId: z.string().uuid(),
        }),
        z.object({
          action: z.literal("end"),
          profileId: z.string().uuid().optional(),
          napId: z.string().uuid().optional(),
        }),
        z.object({
          action: z.literal("create"),
          profileId: z.string().uuid(),
          startedAt: isoDate,
          endedAt: isoDate.nullable().optional(),
        }),
        z.object({
          action: z.literal("createNight"),
          profileId: z.string().uuid(),
          fellAsleepAt: isoDate,
          wokeUpAt: isoDate.nullable().optional(),
        }),
      ])
      .parse(await parseJsonBody(request));

    if (input.action === "start") {
      return changed(await startNap(household, input.profileId));
    }

    if (input.action === "startNight") {
      return changed(await startNightSleep(household, input.profileId));
    }

    if (input.action === "create") {
      return changed(
        await createManualNap(
          household,
          input.profileId,
          new Date(input.startedAt),
          input.endedAt ? new Date(input.endedAt) : null,
        ),
      );
    }

    if (input.action === "createNight") {
      return changed(
        await createNightSleep(
          household,
          input.profileId,
          new Date(input.fellAsleepAt),
          input.wokeUpAt ? new Date(input.wokeUpAt) : null,
        ),
      );
    }

    return changed(
      input.napId
        ? await endNap(household, input.napId)
        : await endNapForProfile(
            household,
            z.string().uuid().parse(input.profileId),
          ),
    );
  } catch (error) {
    return handleMobileError(error);
  }
}
