import { describe, expect, it } from "vitest";
import {
  assignableRoles,
  canManageHousehold,
  evaluateMemberRoleChange,
  isGuest,
  isOwner,
  roleLabel,
} from "./household-roles";

describe("household roles", () => {
  it("identifies managers and guests", () => {
    expect(canManageHousehold("owner")).toBe(true);
    expect(canManageHousehold("parent")).toBe(true);
    expect(canManageHousehold("guest")).toBe(false);
    expect(isGuest("guest")).toBe(true);
    expect(isOwner("owner")).toBe(true);
  });

  it("labels roles for display", () => {
    expect(roleLabel("guest")).toBe("Guest");
    expect(roleLabel("parent")).toBe("Parent");
    expect(roleLabel("owner")).toBe("Owner");
  });

  it("limits assignable roles by actor", () => {
    expect(assignableRoles("owner")).toEqual(["owner", "parent", "guest"]);
    expect(assignableRoles("parent")).toEqual(["parent", "guest"]);
    expect(assignableRoles("guest")).toEqual([]);
  });

  it("lets owners and parents change other members", () => {
    expect(
      evaluateMemberRoleChange({
        actorRole: "parent",
        actorUserId: "adult-1",
        targetUserId: "guest-1",
        targetRole: "guest",
        nextRole: "parent",
        ownerCount: 1,
      }),
    ).toEqual({ ok: true });
    expect(
      evaluateMemberRoleChange({
        actorRole: "owner",
        actorUserId: "owner-1",
        targetUserId: "parent-1",
        targetRole: "parent",
        nextRole: "owner",
        ownerCount: 1,
      }),
    ).toEqual({ ok: true });
  });

  it("blocks unsafe role changes", () => {
    expect(
      evaluateMemberRoleChange({
        actorRole: "parent",
        actorUserId: "adult-1",
        targetUserId: "adult-1",
        targetRole: "parent",
        nextRole: "guest",
        ownerCount: 1,
      }).ok,
    ).toBe(false);
    expect(
      evaluateMemberRoleChange({
        actorRole: "parent",
        actorUserId: "adult-1",
        targetUserId: "owner-1",
        targetRole: "owner",
        nextRole: "parent",
        ownerCount: 1,
      }).ok,
    ).toBe(false);
    expect(
      evaluateMemberRoleChange({
        actorRole: "owner",
        actorUserId: "owner-1",
        targetUserId: "owner-1",
        targetRole: "owner",
        nextRole: "parent",
        ownerCount: 1,
      }).ok,
    ).toBe(false);
    expect(
      evaluateMemberRoleChange({
        actorRole: "owner",
        actorUserId: "owner-1",
        targetUserId: "owner-2",
        targetRole: "owner",
        nextRole: "parent",
        ownerCount: 1,
      }).ok,
    ).toBe(false);
  });
});
