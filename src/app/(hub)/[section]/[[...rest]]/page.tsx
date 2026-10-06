import { notFound } from "next/navigation";
import { IOSOnlyPage } from "@/components/ios-only-page";

// Everything except Settings lives in the iOS app. These are the addresses the old web version used
// (and the one a guest is sent to after signing in), so a saved bookmark or an old link still lands on
// a page that says where things went. Anything else is an ordinary "not found".
const SECTIONS: Record<string, string> = {
  dashboard: "Today",
  calendar: "Calendar",
  routines: "Routines",
  chores: "Chores",
  meals: "Meals",
  recipes: "Recipes",
  snacks: "Snacks",
  groceries: "Groceries",
  notes: "Notes",
  birthdays: "Birthdays",
  sleep: "Sleep",
  naps: "Sleep",
};

export default async function IOSOnlySection({
  params,
}: {
  params: Promise<{ section: string }>;
}) {
  const { section } = await params;
  const name = SECTIONS[section];
  if (!name) notFound();
  return <IOSOnlyPage title={`${name} lives in the iOS app.`} />;
}
