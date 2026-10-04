import { z } from "zod";
import { deleteNap, serializeNap, updateNapTimes } from "@/lib/naps/store";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
} from "@/lib/mobile/http";

export async function PATCH(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  try {
    const household = await requireMobileHousehold();
    const { id } = await context.params;
    const input = z
      .object({
        startedAt: z.string().datetime(),
        endedAt: z.string().datetime().nullable().optional(),
      })
      .parse(await parseJsonBody(request));

    const nap = await updateNapTimes(
      household,
      z.string().uuid().parse(id),
      new Date(input.startedAt),
      input.endedAt ? new Date(input.endedAt) : null,
    );
    // The changed entry rides along so the app does not have to refetch the page.
    return mobileJson({ ok: true, nap: serializeNap(nap) });
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  try {
    const household = await requireMobileHousehold();
    const { id } = await context.params;
    await deleteNap(household, z.string().uuid().parse(id));
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
