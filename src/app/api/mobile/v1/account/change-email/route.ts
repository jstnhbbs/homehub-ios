import { headers } from "next/headers";
import { z } from "zod";
import { auth } from "@/lib/auth";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileUser,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    await requireMobileUser();
    const input = z
      .object({
        newEmail: z.string().trim().email(),
      })
      .parse(await parseJsonBody(request));

    const result = await auth.api.changeEmail({
      body: {
        newEmail: input.newEmail,
        callbackURL: "/dashboard",
      },
      headers: await headers(),
    });

    return mobileJson(result);
  } catch (error) {
    return handleMobileError(error);
  }
}
