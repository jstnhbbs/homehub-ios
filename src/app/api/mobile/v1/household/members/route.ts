import { asc, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { householdMembers, users } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  requireMobileHousehold,
} from "@/lib/mobile/http";

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const rows = await db
      .select({
        userId: householdMembers.userId,
        role: householdMembers.role,
        joinedAt: householdMembers.joinedAt,
        name: users.name,
        email: users.email,
      })
      .from(householdMembers)
      .innerJoin(users, eq(householdMembers.userId, users.id))
      .where(eq(householdMembers.householdId, household.id))
      .orderBy(asc(householdMembers.joinedAt));
    return mobileJson(rows);
  } catch (error) {
    return handleMobileError(error);
  }
}
