#!/usr/bin/env bash
set -euo pipefail

echo "[1/7] Ensuring folders..."
mkdir -p frontend/src/app frontend/src/app/dashboard frontend/src/app/gallery frontend/src/app/settings frontend/src/app/api
mkdir -p frontend/src/app

# Helpers
node_has_pkg () {
  local pkg="$1"
  if [[ -f frontend/package.json ]]; then
    node -e "const p=require('./frontend/package.json'); const d={...(p.dependencies||{}),...(p.devDependencies||{})}; process.exit(d['$pkg']?0:1)"
  else
    return 1
  fi
}

echo "[2/7] Ensuring Tailwind CSS setup..."
# Ensure package.json exists
if [[ ! -f frontend/package.json ]]; then
  echo "frontend/package.json not found. Create Next.js project first (or run your init script)."
  exit 1
fi

# Install tailwind if missing
if ! node_has_pkg "tailwindcss"; then
  echo "  Installing tailwindcss/postcss/autoprefixer..."
  (cd frontend && npm install -D tailwindcss postcss autoprefixer)
fi

# Ensure tailwind config exists (prefer TS if project uses TS)
if [[ ! -f frontend/tailwind.config.ts && ! -f frontend/tailwind.config.js ]]; then
  cat > frontend/tailwind.config.ts <<'TS'
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: ["./src/app/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: "#0b1220",
        panel: "#0f1b2d",
        panel2: "#121f35",
        border: "rgba(255,255,255,0.08)"
      }
    }
  },
  plugins: []
};

export default config;
TS
fi

if [[ ! -f frontend/postcss.config.js && ! -f frontend/postcss.config.cjs ]]; then
  cat > frontend/postcss.config.js <<'JS'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
JS
fi

mkdir -p frontend/src/app
if [[ ! -f frontend/src/app/globals.css ]]; then
  cat > frontend/src/app/globals.css <<'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: dark;
}

html, body {
  height: 100%;
}

body {
  background: #0b1220;
  color: rgba(255,255,255,0.92);
}

a { color: inherit; text-decoration: none; }

* { box-sizing: border-box; }
CSS
fi

echo "[3/7] Writing layout.tsx (global nav + fonts + dark theme)..."
cat > frontend/src/app/layout.tsx <<'TSX'
import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "ai-agency-boss",
  description: "Local AI Advertising Agency Dashboard",
};

const NavItem = ({ href, label }: { href: string; label: string }) => (
  <a
    href={href}
    className="px-3 py-2 rounded-md text-sm text-white/80 hover:text-white hover:bg-white/10 transition"
  >
    {label}
  </a>
);

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tr" className="dark">
      <body className="min-h-screen bg-bg">
        <header className="sticky top-0 z-50 border-b border-[color:var(--tw-prose-borders)] border-white/10 bg-bg/70 backdrop-blur">
          <div className="mx-auto max-w-6xl px-4 py-3 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="h-9 w-9 rounded-xl bg-gradient-to-br from-indigo-500 to-cyan-400" />
              <div className="leading-tight">
                <div className="font-semibold text-white">ai-agency-boss</div>
                <div className="text-xs text-white/60">Dashboard</div>
              </div>
            </div>

            <nav className="flex items-center gap-1">
              <NavItem href="/" label="Dashboard" />
              <NavItem href="/gallery" label="Gallery" />
              <NavItem href="/settings" label="Settings" />
            </nav>
          </div>
        </header>

        <main className="mx-auto max-w-6xl px-4 py-6">{children}</main>

        <footer className="mx-auto max-w-6xl px-4 pb-10 pt-4 text-xs text-white/50">
          Local-only AI • No external APIs
        </footer>
      </body>
    </html>
  );
}
TSX

echo "[4/7] Writing Dashboard page (page.tsx) with Prompt + Report + Gallery..."
cat > frontend/src/app/page.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";

type StrategyReport = {
  target_audience: any[];
  slogan_suggestions: string[];
  campaign_strategy: any;
};

type AnalyzeResponse = {
  user_id: string;
  report: StrategyReport;
};

type GenerateImageResponse = {
  user_id: string;
  output_path: string;
};

function getApiBaseUrl() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

function getToken() {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("jwt") || "";
}

function setToken(token: string) {
  if (typeof window === "undefined") return;
  localStorage.setItem("jwt", token);
}

export default function DashboardPage() {
  const apiBase = useMemo(() => getApiBaseUrl(), []);
  const [jwt, setJwt] = useState("");

  const [businessDescription, setBusinessDescription] = useState(
    "Örn: İstanbul'da yeni açılan butik kahve dükkanı. Hedef: Instagram üzerinden 18-35 yaş kitle. Ton: premium ama samimi."
  );

  const [loadingAnalyze, setLoadingAnalyze] = useState(false);
  const [loadingImage, setLoadingImage] = useState(false);

  const [report, setReport] = useState<StrategyReport | null>(null);
  const [images, setImages] = useState<string[]>([]);
  const [error, setError] = useState<string>("");

  useEffect(() => {
    setJwt(getToken());
  }, []);

  async function analyze() {
    setError("");
    setLoadingAnalyze(true);
    try {
      const res = await fetch(`${apiBase}/analyze`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${jwt}`,
        },
        body: JSON.stringify({ business_description: businessDescription }),
      });

      if (!res.ok) {
        const txt = await res.text();
        throw new Error(`Analyze failed (${res.status}): ${txt}`);
      }

      const data = (await res.json()) as AnalyzeResponse;
      setReport(data.report);
    } catch (e: any) {
      setError(e?.message || "Analyze error");
    } finally {
      setLoadingAnalyze(false);
    }
  }

  async function generateImage(prompt: string) {
    setError("");
    setLoadingImage(true);
    try {
      const res = await fetch(`${apiBase}/generate-image`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${jwt}`,
        },
        body: JSON.stringify({
          prompt,
          width: 512,
          height: 512,
          steps: 30,
          guidance_scale: 7.0,
        }),
      });

      if (!res.ok) {
        const txt = await res.text();
        throw new Error(`Generate-image failed (${res.status}): ${txt}`);
      }

      const data = (await res.json()) as GenerateImageResponse;

      // Backend returns a filesystem path; for now we display it as text.
      // Next step: expose storage/outputs via a static route (e.g., /files/...) so images can be shown as <img>.
      setImages((prev) => [data.output_path, ...prev]);
    } catch (e: any) {
      setError(e?.message || "Generate-image error");
    } finally {
      setLoadingImage(false);
    }
  }

  const bestPrompt = useMemo(() => {
    // If you want: derive a prompt from report later.
    return "A cinematic product photo, dark moody lighting, ultra-detailed, 35mm, shallow depth of field";
  }, [report]);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
      {/* Prompt Panel */}
      <section className="lg:col-span-1 rounded-2xl border border-white/10 bg-panel p-4">
        <h2 className="text-white font-semibold">Prompt</h2>
        <p className="mt-1 text-sm text-white/60">
          İş fikrini yaz, strateji raporu üret, sonra prompt ile görsel üret.
        </p>

        <label className="mt-4 block text-xs text-white/60">JWT (Bearer token)</label>
        <input
          value={jwt}
          onChange={(e) => {
            setJwt(e.target.value);
            setToken(e.target.value);
          }}
          placeholder="Paste JWT here"
          className="mt-1 w-full rounded-xl border border-white/10 bg-panel2 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-cyan-400/40"
        />

        <label className="mt-4 block text-xs text-white/60">Business description</label>
        <textarea
          value={businessDescription}
          onChange={(e) => setBusinessDescription(e.target.value)}
          rows={10}
          className="mt-1 w-full resize-none rounded-xl border border-white/10 bg-panel2 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-400/40"
        />

        <div className="mt-3 flex gap-2">
          <button
            onClick={analyze}
            disabled={loadingAnalyze || !jwt}
            className="flex-1 rounded-xl bg-indigo-500 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-400 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loadingAnalyze ? "Analyzing..." : "Analyze (/analyze)"}
          </button>

          <button
            onClick={() => generateImage(bestPrompt)}
            disabled={loadingImage || !jwt}
            className="flex-1 rounded-xl bg-cyan-500 px-4 py-2 text-sm font-medium text-black hover:bg-cyan-400 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loadingImage ? "Generating..." : "Generate image"}
          </button>
        </div>

        {error ? (
          <div className="mt-3 rounded-xl border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-200">
            {error}
          </div>
        ) : null}

        <div className="mt-4 rounded-xl border border-white/10 bg-black/20 p-3">
          <div className="text-xs text-white/60">Suggested prompt</div>
          <div className="mt-1 text-sm text-white/90">{bestPrompt}</div>
        </div>
      </section>

      {/* Report Panel */}
      <section className="lg:col-span-2 rounded-2xl border border-white/10 bg-panel p-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-white font-semibold">Rapor</h2>
            <p className="mt-1 text-sm text-white/60">
              /analyze çıktısı burada görünecek.
            </p>
          </div>
        </div>

        {!report ? (
          <div className="mt-6 rounded-2xl border border-white/10 bg-black/20 p-6 text-sm text-white/70">
            Henüz rapor yok. Soldan <span className="text-white">Analyze</span> ile üret.
          </div>
        ) : (
          <div className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-3">
            <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
              <div className="text-xs text-white/60">Target audience</div>
              <pre className="mt-2 overflow-auto text-xs text-white/85">
{JSON.stringify(report.target_audience, null, 2)}
              </pre>
            </div>

            <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
              <div className="text-xs text-white/60">Slogan suggestions</div>
              <ul className="mt-2 space-y-2 text-sm text-white/85">
                {report.slogan_suggestions?.map((s, i) => (
                  <li key={i} className="rounded-xl bg-white/5 px-3 py-2 border border-white/10">
                    {s}
                  </li>
                ))}
              </ul>
            </div>

            <div className="md:col-span-2 rounded-2xl border border-white/10 bg-black/20 p-4">
              <div className="text-xs text-white/60">Campaign strategy</div>
              <pre className="mt-2 overflow-auto text-xs text-white/85">
{JSON.stringify(report.campaign_strategy, null, 2)}
              </pre>
            </div>
          </div>
        )}

        {/* Gallery Panel */}
        <div className="mt-6">
          <h3 className="text-white font-semibold">Galeri</h3>
          <p className="mt-1 text-sm text-white/60">
            Şimdilik backend bir dosya yolu döndürüyor. Bir sonraki adımda bu klasörü statik olarak servis edip görselleri burada gerçek <code className="text-white/80">img</code> olarak göstereceğiz.
          </p>

          {images.length === 0 ? (
            <div className="mt-3 rounded-2xl border border-white/10 bg-black/20 p-6 text-sm text-white/70">
              Henüz görsel yok.
            </div>
          ) : (
            <div className="mt-3 grid grid-cols-1 md:grid-cols-2 gap-3">
              {images.map((p, idx) => (
                <div key={idx} className="rounded-2xl border border-white/10 bg-black/20 p-4">
                  <div className="text-xs text-white/60">Output path</div>
                  <div className="mt-1 text-sm text-white/90 break-all">{p}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
TSX

echo "[5/7] Creating minimal Gallery + Settings pages..."
cat > frontend/src/app/gallery/page.tsx <<'TSX'
export default function GalleryPage() {
  return (
    <section className="rounded-2xl border border-white/10 bg-panel p-4">
      <h2 className="text-white font-semibold">Gallery</h2>
      <p className="mt-1 text-sm text-white/60">
        Dashboard'da üretilen görseller burada listelenecek (sonraki adım: backend outputs'u statik servis).
      </p>
    </section>
  );
}
TSX

cat > frontend/src/app/settings/page.tsx <<'TSX'
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
TSX

echo "[6/7] Ensuring Next.js app router entry files exist..."
# Ensure root app directory exists (already created)
if [[ ! -f frontend/src/app/favicon.ico ]]; then
  # optional; skip
  true
fi

echo "[7/7] Done."
echo ""
echo "Run:"
echo "  (cd frontend && npm install)"
echo "  docker compose up --build"
echo ""
echo "Make sure docker-compose sets NEXT_PUBLIC_API_BASE_URL=http://localhost:8000"