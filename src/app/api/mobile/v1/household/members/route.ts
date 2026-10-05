import { asc, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { canManageHousehold } from "@/lib/household-roles";
import { householdMembers, users } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  requireMobileHousehold,
} from "@/lib/mobile/http";

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const canSeeEmails = canManageHousehold(household.role);
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
    // Parents manage the members, so they need to tell people apart by email. A guest sees who is in
    // the household and in what role, not anyone's address. Empty rather than missing, because older
    // app versions decode the field as required.
    return mobileJson(rows.map((row) => ({ ...row, email: canSeeEmails ? row.email : "" })));
  } catch (error) {
    return handleMobileError(error);
  }
}
