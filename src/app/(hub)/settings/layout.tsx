import { redirect } from "next/navigation";
import { requireHousehold } from "@/lib/household";
import { isGuest } from "@/lib/household-roles";

export default async function SettingsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const household = await requireHousehold();
  if (isGuest(household.role)) redirect("/dashboard");
  return children;
}
