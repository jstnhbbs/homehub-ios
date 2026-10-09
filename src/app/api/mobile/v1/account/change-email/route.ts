import { eq } from "drizzle-orm";
import { headers } from "next/headers";
import { z } from "zod";
import { db } from "@/db/client";
import { users } from "@/db/schema";
import { auth } from "@/lib/auth";
import { canSendEmail } from "@/lib/email";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileUser,
} from "@/lib/mobile/http";

/**
 * Starts an email change. In production the address only changes once the link sent to the new
 * address is followed, so the answer says which happened: `emailChanged` is true when it changed at
 * once (development, for an unconfirmed address) and false when a link is on its way. Without an
 * email provider no link could arrive, so the request is refused rather than appearing to work.
 */
export async function POST(request: Request) {
  try {
    const user = await requireMobileUser();
    const input = z
      .object({
        newEmail: z.string().trim().email(),
      })
      .parse(await parseJsonBody(request));

    if (!canSendEmail()) {
      throw new Error("Changing your email isn't available yet.");
    }

    const result = await auth.api.changeEmail({
      body: {
        newEmail: input.newEmail,
        callbackURL: "/settings",
      },
      headers: await headers(),
    });

    const [current] = await db
      .select({ email: users.email })
      .from(users)
      .where(eq(users.id, user.id))
      .limit(1);
    const emailChanged = current?.email.toLowerCase() === input.newEmail.toLowerCase();

    return mobileJson({ ...result, emailChanged });
  } catch (error) {
    return handleMobileError(error);
  }
}
