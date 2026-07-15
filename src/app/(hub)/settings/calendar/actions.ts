"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { connectICloud, disconnectICloud } from "@/lib/caldav/client";
import { requireHousehold } from "@/lib/household";
import { checkRateLimit } from "@/lib/rate-limit";

export async function connectCalendar(formData: FormData) {
  const household = await requireHousehold();
  const allowed = await checkRateLimit("calendar-connect", household.id, {
    limit: 5,
    windowMs: 15 * 60 * 1000,
  });
  if (!allowed) throw new Error("Too many connection attempts. Try again later.");
  const input = z
    .object({
      username: z.string().trim().email(),
      password: z.string().trim().min(16).max(32),
    })
    .parse({
      username: formData.get("username"),
      password: formData.get("password"),
    });
  await connectICloud({
    householdId: household.id,
    username: input.username,
    appSpecificPassword: input.password.replaceAll("-", ""),
  });
  revalidatePath("/", "layout");
}

export async function disconnectCalendar() {
  const household = await requireHousehold();
  await disconnectICloud(household.id);
  revalidatePath("/", "layout");
}
