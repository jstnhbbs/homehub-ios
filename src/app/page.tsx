import { redirect } from "next/navigation";
import { getCurrentHousehold, getSession } from "@/lib/household";

export default async function Home() {
  const session = await getSession();
  if (!session) redirect("/sign-in");
  const household = await getCurrentHousehold();
  redirect(household ? "/dashboard" : "/onboarding");
}
