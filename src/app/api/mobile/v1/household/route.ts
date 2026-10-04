import { randomUUID } from "node:crypto";
import { eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { householdMembers, households, profiles, users } from "@/db/schema";
import { getCurrentHousehold } from "@/lib/household";
import { generateInviteCodePair } from "@/lib/invite-codes";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileUser,
  serializeHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

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
        ownerLastName: z.string().trim().min(1).max(80),
        childName: z.string().trim().max(60).optional(),
        timezone: z.string().trim().min(1).max(80),
      })
      .parse(await parseJsonBody(request));

    const id = randomUUID();
    const { inviteCode, guestInviteCode } = generateInviteCodePair();

    await db.transaction(async (tx) => {
      await tx.insert(households).values({
        id,
        name: input.name,
        timezone: input.timezone,
        inviteCode,
        guestInviteCode,
      });
      await tx
        .update(users)
        .set({
          name: nameWithRequiredSurname(user.name, input.ownerLastName),
          updatedAt: new Date(),
        })
        .where(eq(users.id, user.id));
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

function nameWithRequiredSurname(currentName: string, lastName: string) {
  const cleanName = currentName.trim();
  const cleanLastName = lastName.trim();
  if (!cleanName) return cleanLastName;

  const parts = cleanName.split(/\s+/);
  const currentLast = parts.at(-1);
  if (currentLast?.localeCompare(cleanLastName, undefined, { sensitivity: "accent" }) === 0) {
    return cleanName;
  }

  if (parts.length === 1) {
    return `${cleanName} ${cleanLastName}`;
  }

  return `${parts.slice(0, -1).join(" ")} ${cleanLastName}`;
}
