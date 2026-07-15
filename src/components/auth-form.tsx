"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { authClient } from "@/lib/auth-client";

export function AuthForm() {
  const router = useRouter();
  const [mode, setMode] = useState<"sign-in" | "sign-up">("sign-in");
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setError("");
    const form = new FormData(event.currentTarget);
    const email = String(form.get("email"));
    const password = String(form.get("password"));
    const name = String(form.get("name") || "Parent");
    const result =
      mode === "sign-up"
        ? await authClient.signUp.email({ email, password, name })
        : await authClient.signIn.email({ email, password });
    setPending(false);
    if (result.error) {
      setError(result.error.message ?? "We could not sign you in.");
      return;
    }
    router.push("/");
    router.refresh();
  }

  return (
    <form onSubmit={submit} className="mt-8 space-y-4">
      {mode === "sign-up" && (
        <label className="block">
          <span className="mb-1.5 block text-sm font-bold">Your name</span>
          <input className="hub-input" name="name" autoComplete="name" required />
        </label>
      )}
      <label className="block">
        <span className="mb-1.5 block text-sm font-bold">Email</span>
        <input
          className="hub-input"
          name="email"
          type="email"
          autoComplete="email"
          required
        />
      </label>
      <label className="block">
        <span className="mb-1.5 block text-sm font-bold">Password</span>
        <input
          className="hub-input"
          name="password"
          type="password"
          autoComplete={mode === "sign-up" ? "new-password" : "current-password"}
          minLength={10}
          required
        />
      </label>
      {error && (
        <p role="alert" className="rounded-xl bg-[var(--coral-soft)] p-3 text-sm">
          {error}
        </p>
      )}
      <button className="hub-button w-full" disabled={pending}>
        {pending
          ? "Just a moment…"
          : mode === "sign-up"
            ? "Create parent account"
            : "Sign in"}
      </button>
      <button
        type="button"
        className="w-full py-2 text-sm font-bold text-[var(--sage)]"
        onClick={() => {
          setMode(mode === "sign-in" ? "sign-up" : "sign-in");
          setError("");
        }}
      >
        {mode === "sign-in"
          ? "New here? Create an account"
          : "Already have an account? Sign in"}
      </button>
    </form>
  );
}
