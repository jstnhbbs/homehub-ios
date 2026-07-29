import { MealsSubNav } from "@/components/meals-sub-nav";
import { requireUser } from "@/lib/household";
import { getUserHubModules } from "@/lib/hub-modules-store";

export default async function MealsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireUser();
  const hubModules = await getUserHubModules(user.id);

  return (
    <>
      <MealsSubNav modules={hubModules} />
      {children}
    </>
  );
}
