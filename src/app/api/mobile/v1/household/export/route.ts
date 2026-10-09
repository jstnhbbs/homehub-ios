import { buildHouseholdExport } from "@/lib/household-export";
import {
  handleMobileError,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function GET() {
  try {
    const household = await requireMobileParentHousehold();
    const data = await buildHouseholdExport(household.id);
    return new Response(JSON.stringify(data, null, 2), {
      headers: {
        "Content-Type": "application/json",
        "Content-Disposition": 'attachment; filename="porchlight-export.json"',
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    return handleMobileError(error);
  }
}
