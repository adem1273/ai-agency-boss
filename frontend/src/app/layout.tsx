import "./globals.css";
import type { Metadata } from "next";
import { Inter, Syne } from "next/font/google";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const syne = Syne({
  subsets: ["latin"],
  variable: "--font-syne",
  weight: ["600", "700", "800"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "AI Agency Boss — Yapay Zeka Reklam Ajansı",
  description: "Dakikalar içinde reklam stratejisi, AI görsel ve video üretimi. Tamamen yerel.",
};

const NavItem = ({ href, label }: { href: string; label: string }) => (
  <a
    href={href}
    className="px-3 py-2 rounded-lg text-sm text-white/60 hover:text-white hover:bg-white/[0.07] transition-all duration-150"
  >
    {label}
  </a>
);

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tr" className={`dark ${inter.variable} ${syne.variable}`}>
      <body className="min-h-screen bg-bg">
        {/* Header */}
        <header className="sticky top-0 z-50 border-b border-white/[0.07] bg-bg/80 backdrop-blur-xl">
          <div className="mx-auto max-w-6xl px-4 py-3.5 flex items-center justify-between">
            {/* Logo */}
            <a href="/" className="flex items-center gap-3 group">
              <div className="relative h-9 w-9 flex-shrink-0 rounded-xl overflow-hidden">
                <div className="absolute inset-0 bg-gradient-to-br from-amber-400 via-orange-500 to-indigo-600" />
                <span className="absolute inset-0 flex items-center justify-center font-display font-bold text-white text-sm">A</span>
              </div>
              <div className="leading-tight">
                <div className="font-display font-bold text-white text-[15px] tracking-tight group-hover:text-amber-400 transition-colors">
                  AI Agency Boss
                </div>
                <div className="text-[10px] text-white/35 font-medium tracking-widest uppercase">
                  Reklam Ajansı
                </div>
              </div>
            </a>

            {/* Nav */}
            <nav className="flex items-center gap-1">
              <NavItem href="/" label="Dashboard" />
              <NavItem href="/gallery" label="Galeri" />
              <NavItem href="/settings" label="Ayarlar" />
              <a
                href="#dashboard"
                className="ml-3 inline-flex items-center gap-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 px-4 py-2 text-sm font-semibold text-white transition-colors"
              >
                Başla <span>→</span>
              </a>
            </nav>
          </div>
        </header>

        <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>

        {/* Footer */}
        <footer className="border-t border-white/[0.06] mt-16">
          <div className="mx-auto max-w-6xl px-4 py-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-white/30">
            <span className="font-display font-semibold text-white/40 text-sm">AI Agency Boss</span>
            <span>Yerel AI &bull; Dış API Yok &bull; Tam Gizlilik</span>
          </div>
        </footer>
      </body>
    </html>
  );
}
