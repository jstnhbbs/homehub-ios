import { z } from "zod";
import { suggestTags } from "@/lib/recipes/tags";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const inputSchema = z.object({
  title: z.string().trim().max(200).default(""),
  ingredients: z.array(z.string().trim().max(300)).max(80).default([]),
});

/** Suggests tags for a recipe being edited, using the same rules as URL import. */
export async function POST(request: Request) {
  try {
    await requireMobileParentHousehold();
    const input = inputSchema.parse(await parseJsonBody(request));
    return mobileJson({ tags: suggestTags(input) });
  } catch (error) {
    return handleMobileError(error);
  }
}
