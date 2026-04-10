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
