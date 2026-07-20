import { randomBytes, randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { householdMembers, households, profiles } from "@/db/schema";
import { getCurrentHousehold } from "@/lib/household";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileUser,
  serializeHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

function generateInviteCode() {
  return randomBytes(4).toString("hex").toUpperCase();
}

export async function GET() {
  try {
    await requireMobileUser();
    const household = await getCurrentHousehold();
    return mobileJson(household ? serializeHousehold(household) : null);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const user = await requireMobileUser();
    const input = z
      .object({
        name: shortText,
        childName: z.string().trim().max(60).optional(),
        timezone: z.string().trim().min(1).max(80),
      })
      .parse(await parseJsonBody(request));

    const id = randomUUID();
    const inviteCode = generateInviteCode();
    let guestInviteCode = generateInviteCode();
    while (guestInviteCode === inviteCode) {
      guestInviteCode = generateInviteCode();
    }

    await db.transaction(async (tx) => {
      await tx.insert(households).values({
        id,
        name: input.name,
        timezone: input.timezone,
        inviteCode,
        guestInviteCode,
      });
      await tx.insert(householdMembers).values({
        householdId: id,
        userId: user.id,
        role: "owner",
      });
      if (input.childName) {
        await tx.insert(profiles).values({
          id: randomUUID(),
          householdId: id,
          name: input.childName,
          color: "#d87861",
        });
      }
    });

    const household = await getCurrentHousehold();
    return mobileJson(serializeHousehold(household!), 201);
  } catch (error) {
    return handleMobileError(error);
  }
}
