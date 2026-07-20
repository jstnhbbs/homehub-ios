import { eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { householdMembers, households } from "@/db/schema";
import { getCurrentHousehold } from "@/lib/household";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  serializeHousehold,
  requireMobileUser,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const user = await requireMobileUser();
    const inviteCode = z
      .string()
      .trim()
      .transform((value) => value.toUpperCase())
      .parse((await parseJsonBody<{ inviteCode: string }>(request)).inviteCode);

    const household = await db
      .select({ id: households.id })
      .from(households)
      .where(eq(households.inviteCode, inviteCode))
      .limit(1);
    if (!household[0]) throw new Error("That invite code was not found.");

    await db
      .insert(householdMembers)
      .values({
        householdId: household[0].id,
        userId: user.id,
        role: "parent",
      })
      .onConflictDoNothing();

    const current = await getCurrentHousehold();
    return mobileJson(serializeHousehold(current!));
  } catch (error) {
    return handleMobileError(error);
  }
}
