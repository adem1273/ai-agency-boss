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
  output_url: string;
};

type GeneratedImage = {
  path: string;
  url: string;
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
  const [images, setImages] = useState<GeneratedImage[]>([]);
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
      const imageUrl = `${apiBase}${data.output_url}`;
      setImages((prev) => [{ path: data.output_path, url: imageUrl }, ...prev]);
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
            Uretilen gorseller backend uzerinden servis edilip burada onizlenir.
          </p>

          {images.length === 0 ? (
            <div className="mt-3 rounded-2xl border border-white/10 bg-black/20 p-6 text-sm text-white/70">
              Henüz görsel yok.
            </div>
          ) : (
            <div className="mt-3 grid grid-cols-1 md:grid-cols-2 gap-3">
              {images.map((img, idx) => (
                <div key={idx} className="rounded-2xl border border-white/10 bg-black/20 p-4">
                  <img
                    src={img.url}
                    alt={`Generated ${idx + 1}`}
                    className="h-auto w-full rounded-xl border border-white/10 bg-black/30"
                    loading="lazy"
                  />
                  <div className="mt-2 text-xs text-white/60">Output path</div>
                  <div className="mt-1 text-xs text-white/80 break-all">{img.path}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
