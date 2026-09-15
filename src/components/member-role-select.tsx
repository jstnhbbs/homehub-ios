"use client";

import { useTransition } from "react";
import { updateMemberRole } from "@/app/actions";
import { roleLabel, type HouseholdRole } from "@/lib/household-roles";

export function MemberRoleSelect({
  userId,
  role,
  options,
}: {
  userId: string;
  role: HouseholdRole;
  options: HouseholdRole[];
}) {
  const [isPending, startTransition] = useTransition();

  return (
    <select
      className="hub-input w-auto py-1 text-xs font-bold"
      defaultValue={role}
      disabled={isPending}
      aria-label="Member role"
      onChange={(event) => {
        const nextRole = event.target.value as HouseholdRole;
        if (nextRole === role) return;
        const formData = new FormData();
        formData.set("userId", userId);
        formData.set("role", nextRole);
        startTransition(async () => {
          await updateMemberRole(formData);
        });
      }}
    >
      {options.map((option) => (
        <option key={option} value={option}>
          {roleLabel(option)}
        </option>
      ))}
    </select>
  );
}
