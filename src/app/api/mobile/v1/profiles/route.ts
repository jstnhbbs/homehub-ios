import { randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { isProfileColor } from "@/lib/profile-colors";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const rows = await db
      .select()
      .from(profiles)
      .where(eq(profiles.householdId, household.id))
      .orderBy(asc(profiles.sortOrder));
    return mobileJson(rows);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = z
      .object({
        name: shortText,
        profileType: z.enum(["adult", "child"]),
        color: z.string(),
        birthday: z.string().date().optional(),
      })
      .parse(await parseJsonBody(request));

    if (!isProfileColor(input.color)) {
      throw new Error("Invalid profile color.");
    }

    const row = {
      id: randomUUID(),
      householdId: household.id,
      name: input.name,
      profileType: input.profileType,
      color: input.color,
      birthday: input.birthday ?? null,
    };
    await db.insert(profiles).values(row);
    return mobileJson(row, 201);
  } catch (error) {
    return handleMobileError(error);
  }
}
