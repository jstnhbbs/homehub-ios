import { headers } from "next/headers";
import { z } from "zod";
import { auth } from "@/lib/auth";
import {
  getMobileSession,
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
        currentPassword: z.string().min(1),
        newPassword: z.string().min(10),
        revokeOtherSessions: z.boolean().optional(),
      })
      .parse(await parseJsonBody(request));

    const result = await auth.api.changePassword({
      body: {
        currentPassword: input.currentPassword,
        newPassword: input.newPassword,
        revokeOtherSessions: input.revokeOtherSessions ?? true,
      },
      headers: await headers(),
    });

    return mobileJson(result);
  } catch (error) {
    return handleMobileError(error);
  }
}
