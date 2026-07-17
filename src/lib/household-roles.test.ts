import { describe, expect, it } from "vitest";
import { canManageHousehold, isGuest, roleLabel } from "./household-roles";

describe("household roles", () => {
  it("identifies managers and guests", () => {
    expect(canManageHousehold("owner")).toBe(true);
    expect(canManageHousehold("parent")).toBe(true);
    expect(canManageHousehold("guest")).toBe(false);
    expect(isGuest("guest")).toBe(true);
  });

  it("labels roles for display", () => {
    expect(roleLabel("guest")).toBe("Guest");
    expect(roleLabel("parent")).toBe("Parent");
  });
});
