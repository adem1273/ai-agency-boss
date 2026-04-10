"use client";

import { useEffect, useState } from "react";

export default function SettingsPage() {
  const [jwt, setJwt] = useState("");

  useEffect(() => {
    setJwt(localStorage.getItem("jwt") || "");
  }, []);

  return (
    <section className="rounded-2xl border border-white/10 bg-panel p-4">
      <h2 className="text-white font-semibold">Settings</h2>
      <p className="mt-1 text-sm text-white/60">
        Şimdilik sadece JWT saklama alanı var.
      </p>

      <label className="mt-4 block text-xs text-white/60">JWT</label>
      <input
        value={jwt}
        onChange={(e) => {
          setJwt(e.target.value);
          localStorage.setItem("jwt", e.target.value);
        }}
        className="mt-1 w-full rounded-xl border border-white/10 bg-panel2 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-cyan-400/40"
        placeholder="Paste JWT here"
      />
    </section>
  );
}
