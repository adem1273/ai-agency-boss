"use client";

import { useEffect, useMemo, useState } from "react";

// ── Types ────────────────────────────────────────────────
type StrategyReport = {
  target_audience: any[];
  slogan_suggestions: string[];
  campaign_strategy: any;
};
type AnalyzeResponse   = { user_id: string; report: StrategyReport };
type GenerateImageResponse = { user_id: string; output_path: string; output_url: string };
type GeneratedImage    = { path: string; url: string };

// ── Helpers ──────────────────────────────────────────────
function getApiBaseUrl() { return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000"; }
function getToken()      { if (typeof window === "undefined") return ""; return localStorage.getItem("jwt") || ""; }
function setToken(t: string) { if (typeof window !== "undefined") localStorage.setItem("jwt", t); }

// ── Static data ──────────────────────────────────────────
const FEATURES = [
  {
    icon: "⚡",
    title: "Anında Strateji",
    desc: "İş fikrini yaz, 3 dakikada hedef kitle analizi, slogan ve 7 günlük kampanya planı elde et.",
    grad: "from-amber-500/[0.14] to-amber-500/0",
    hb: "hover:border-amber-500/30",
  },
  {
    icon: "🎨",
    title: "AI Görsel Üretimi",
    desc: "Stable Diffusion ile ürün fotoğrafı, banner ve sosyal medya görseli üret. Sıfır API ücreti.",
    grad: "from-indigo-500/[0.14] to-indigo-500/0",
    hb: "hover:border-indigo-500/30",
  },
  {
    icon: "🎬",
    title: "Video Birleştirme",
    desc: "Kliplerinizi FFmpeg ile saniyeler içinde birleştir. Yüksek kaliteli MP4 çıktısı.",
    grad: "from-cyan-500/[0.14] to-cyan-500/0",
    hb: "hover:border-cyan-500/30",
  },
] as const;

const STATS = [
  { value: "3 dk",  label: "Strateji Süresi" },
  { value: "%87",   label: "Dönüşüm Artışı" },
  { value: "∞",     label: "Görsel Üretimi" },
  { value: "100%",  label: "Gizlilik" },
] as const;

// ── Component ────────────────────────────────────────────
export default function DashboardPage() {
  const apiBase = useMemo(() => getApiBaseUrl(), []);

  const [jwt, setJwt] = useState("");
  const [businessDescription, setBusinessDescription] = useState(
    "Örn: İstanbul'da yeni açılan butik kahve dükkanı. Hedef: Instagram üzerinden 18-35 yaş kitle. Ton: premium ama samimi."
  );
  const [loadingAnalyze, setLoadingAnalyze] = useState(false);
  const [loadingImage, setLoadingImage] = useState(false);
  const [report, setReport]   = useState<StrategyReport | null>(null);
  const [images, setImages]   = useState<GeneratedImage[]>([]);
  const [error, setError]     = useState<string>("");

  useEffect(() => { setJwt(getToken()); }, []);

  async function analyze() {
    setError(""); setLoadingAnalyze(true);
    try {
      const res = await fetch(`${apiBase}/analyze`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${jwt}` },
        body: JSON.stringify({ business_description: businessDescription }),
      });
      if (!res.ok) throw new Error(`Analyze failed (${res.status}): ${await res.text()}`);
      const data = (await res.json()) as AnalyzeResponse;
      setReport(data.report);
    } catch (e: any) { setError(e?.message || "Analyze error"); }
    finally { setLoadingAnalyze(false); }
  }

  async function generateImage(prompt: string) {
    setError(""); setLoadingImage(true);
    try {
      const res = await fetch(`${apiBase}/generate-image`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${jwt}` },
        body: JSON.stringify({ prompt, width: 512, height: 512, steps: 30, guidance_scale: 7.0 }),
      });
      if (!res.ok) throw new Error(`Generate-image failed (${res.status}): ${await res.text()}`);
      const data = (await res.json()) as GenerateImageResponse;
      setImages((prev) => [{ path: data.output_path, url: `${apiBase}${data.output_url}` }, ...prev]);
    } catch (e: any) { setError(e?.message || "Generate-image error"); }
    finally { setLoadingImage(false); }
  }

  const bestPrompt = useMemo(
    () => "A cinematic product photo, dark moody lighting, ultra-detailed, 35mm, shallow depth of field",
    [report]
  );

  return (
    <div className="space-y-8">

      {/* ── HERO ─────────────────────────────────────────── */}
      <section className="hero-bg relative overflow-hidden rounded-3xl border border-white/[0.07] px-6 py-16 text-center md:px-16 fade-in-up">
        {/* Glow orbs */}
        <div className="pointer-events-none absolute -left-28 -top-28 h-80 w-80 rounded-full bg-indigo-600/25 blur-3xl" />
        <div className="pointer-events-none absolute -right-28 -bottom-20 h-80 w-80 rounded-full bg-cyan-500/20 blur-3xl" />
        <div className="pointer-events-none absolute left-1/2 top-1/3 h-48 w-48 -translate-x-1/2 rounded-full bg-amber-500/10 blur-3xl" />

        {/* Badge */}
        <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-amber-400/25 bg-amber-400/[0.09] px-4 py-1.5 text-xs font-semibold text-amber-300 tracking-widest uppercase">
          <span className="pulse-dot h-1.5 w-1.5 rounded-full bg-amber-400" />
          AI Destekli Reklam Ajansı
        </div>

        {/* Headline */}
        <h1 className="font-display text-4xl font-extrabold leading-tight text-white md:text-5xl lg:text-6xl">
          Rakiplerinizin Önüne<br />
          <span className="gradient-text">Yapay Zeka ile Geçin</span>
        </h1>

        {/* Subheadline */}
        <p className="mx-auto mt-5 max-w-xl text-base leading-relaxed text-white/55 md:text-lg">
          Dakikalar içinde profesyonel reklam stratejisi üret, AI görseller oluştur ve
          kampanyalarını otomatik yönet.{" "}
          <span className="font-medium text-white/75">Tamamen yerel — verilerin asla dışarı çıkmaz.</span>
        </p>

        {/* CTAs */}
        <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <a href="#dashboard" className="btn-gold group">
            Hemen Başla
            <span className="transition-transform group-hover:translate-x-1">→</span>
          </a>
          <a href="#features" className="btn-ghost">Özellikleri Keşfet</a>
        </div>

        {/* Stats */}
        <div className="mt-12 flex flex-wrap items-center justify-center gap-8 border-t border-white/[0.08] pt-8">
          {STATS.map((s) => (
            <div key={s.label} className="text-center">
              <div className="font-display text-2xl font-bold text-white">{s.value}</div>
              <div className="mt-0.5 text-[10px] uppercase tracking-widest text-white/40">{s.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ── FEATURES ─────────────────────────────────────── */}
      <section id="features" className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        {FEATURES.map((f) => (
          <div
            key={f.title}
            className={`feature-card rounded-2xl border border-white/[0.07] ${f.hb} bg-gradient-to-br ${f.grad} p-6 transition-colors duration-200`}
          >
            <div className="mb-3 text-3xl">{f.icon}</div>
            <h3 className="font-display mb-2 font-bold text-white">{f.title}</h3>
            <p className="text-sm leading-relaxed text-white/50">{f.desc}</p>
          </div>
        ))}
      </section>

      {/* ── DASHBOARD TOOL ───────────────────────────────── */}
      <div id="dashboard" className="grid grid-cols-1 lg:grid-cols-3 gap-4">

        {/* Left: Prompt Panel */}
        <section className="lg:col-span-1 rounded-2xl border border-white/[0.07] bg-panel p-5">
          <div className="mb-5">
            <h2 className="font-display font-bold text-white">Strateji Oluştur</h2>
            <p className="mt-1 text-xs text-white/40">İş fikrini yaz, rapor ve görsel üret.</p>
          </div>

          <label className="mb-1.5 block text-[11px] font-semibold uppercase tracking-wider text-white/40">
            JWT Tokeni
          </label>
          <input
            value={jwt}
            onChange={(e) => { setJwt(e.target.value); setToken(e.target.value); }}
            placeholder="Bearer token yapıştır..."
            className="w-full rounded-xl border border-white/[0.08] bg-panel2 px-3 py-2.5 text-sm text-white outline-none placeholder:text-white/20 focus:ring-2 focus:ring-indigo-500/40 transition"
          />

          <label className="mb-1.5 mt-4 block text-[11px] font-semibold uppercase tracking-wider text-white/40">
            İş Tanımı
          </label>
          <textarea
            value={businessDescription}
            onChange={(e) => setBusinessDescription(e.target.value)}
            rows={9}
            className="w-full resize-none rounded-xl border border-white/[0.08] bg-panel2 px-3 py-2.5 text-sm text-white outline-none placeholder:text-white/20 focus:ring-2 focus:ring-indigo-500/40 transition leading-relaxed"
          />

          <div className="mt-3 flex gap-2">
            <button
              onClick={analyze}
              disabled={loadingAnalyze || !jwt}
              className="flex-1 rounded-xl bg-indigo-600 px-3 py-2.5 text-sm font-semibold text-white hover:bg-indigo-500 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              {loadingAnalyze
                ? <span className="flex items-center justify-center gap-2"><span className="spin h-3 w-3 rounded-full border-2 border-white/30 border-t-white" />Analiz...</span>
                : "⚡ Strateji Üret"}
            </button>
            <button
              onClick={() => generateImage(bestPrompt)}
              disabled={loadingImage || !jwt}
              className="flex-1 rounded-xl bg-amber-500 px-3 py-2.5 text-sm font-semibold text-black hover:bg-amber-400 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              {loadingImage
                ? <span className="flex items-center justify-center gap-2"><span className="spin h-3 w-3 rounded-full border-2 border-black/30 border-t-black" />Üretiliyor...</span>
                : "🎨 Görsel Üret"}
            </button>
          </div>

          {error && (
            <div className="mt-3 rounded-xl border border-red-500/25 bg-red-500/[0.09] px-3 py-2.5 text-xs text-red-300 leading-relaxed">
              {error}
            </div>
          )}

          <div className="mt-4 rounded-xl border border-white/[0.06] bg-black/20 p-3">
            <div className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-white/30">Öneri Prompt</div>
            <div className="text-xs leading-relaxed text-white/55">{bestPrompt}</div>
          </div>
        </section>

        {/* Right: Report + Gallery */}
        <section className="lg:col-span-2 rounded-2xl border border-white/[0.07] bg-panel p-5">
          <div className="mb-5">
            <h2 className="font-display font-bold text-white">Strateji Raporu</h2>
            <p className="mt-1 text-xs text-white/40">/analyze çıktısı burada görünecek.</p>
          </div>

          {!report ? (
            <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-white/[0.09] bg-black/10 py-14 text-center">
              <div className="mb-3 text-4xl">📊</div>
              <div className="text-sm font-medium text-white/45">Henüz rapor yok</div>
              <div className="mt-1 text-xs text-white/25">
                Soldan <span className="text-white/45 font-semibold">Strateji Üret</span> butonuna bas.
              </div>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div className="rounded-2xl border border-white/[0.07] bg-black/20 p-4">
                <div className="mb-2 text-[10px] font-semibold uppercase tracking-wider text-white/30">Hedef Kitle</div>
                <pre className="overflow-auto whitespace-pre-wrap text-xs leading-relaxed text-white/70">
                  {JSON.stringify(report.target_audience, null, 2)}
                </pre>
              </div>
              <div className="rounded-2xl border border-white/[0.07] bg-black/20 p-4">
                <div className="mb-2 text-[10px] font-semibold uppercase tracking-wider text-white/30">Slogan Önerileri</div>
                <ul className="space-y-2">
                  {report.slogan_suggestions?.map((s, i) => (
                    <li key={i} className="rounded-xl border border-white/[0.07] bg-white/[0.04] px-3 py-2 text-sm text-white/75">
                      {s}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="md:col-span-2 rounded-2xl border border-white/[0.07] bg-black/20 p-4">
                <div className="mb-2 text-[10px] font-semibold uppercase tracking-wider text-white/30">Kampanya Stratejisi</div>
                <pre className="overflow-auto whitespace-pre-wrap text-xs leading-relaxed text-white/70">
                  {JSON.stringify(report.campaign_strategy, null, 2)}
                </pre>
              </div>
            </div>
          )}

          {/* Gallery */}
          <div className="mt-6">
            <h3 className="font-display font-bold text-white">Oluşturulan Görseller</h3>
            <p className="mt-1 mb-4 text-xs text-white/35">Backend üzerinden servis edilen AI görselleri.</p>

            {images.length === 0 ? (
              <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-white/[0.09] bg-black/10 py-10 text-center">
                <div className="mb-2 text-3xl">🖼️</div>
                <div className="text-sm text-white/35">Henüz görsel yok</div>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {images.map((img, idx) => (
                  <div key={idx} className="overflow-hidden rounded-2xl border border-white/[0.07] bg-black/20">
                    <img
                      src={img.url}
                      alt={`Generated ${idx + 1}`}
                      className="h-auto w-full bg-black/30"
                      loading="lazy"
                    />
                    <div className="px-4 py-3">
                      <div className="truncate text-[10px] text-white/25">{img.path}</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
