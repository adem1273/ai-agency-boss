import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: ["./src/app/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        bg:     "#040d1a",
        panel:  "#071428",
        panel2: "#0a1930",
        gold: {
          "300": "#fcd34d",
          "400": "#fbbf24",
          "500": "#f59e0b",
          "600": "#d97706",
        },
        brand: {
          "400": "#818cf8",
          "500": "#6366f1",
          "600": "#4f46e5",
        },
        accent: {
          "400": "#22d3ee",
          "500": "#06b6d4",
        },
      },
      fontFamily: {
        sans:    ["var(--font-inter)", "system-ui", "sans-serif"],
        display: ["var(--font-syne)", "system-ui", "sans-serif"],
      },
      backgroundImage: {
        "hero-glow":
          "radial-gradient(ellipse at 18% 50%, rgba(99,102,241,0.18) 0%, transparent 55%), radial-gradient(ellipse at 82% 30%, rgba(6,182,212,0.14) 0%, transparent 55%), radial-gradient(ellipse at 55% 88%, rgba(245,158,11,0.07) 0%, transparent 45%)",
      },
      boxShadow: {
        gold:      "0 0 36px rgba(245,158,11,0.35), 0 4px 20px rgba(0,0,0,0.45)",
        "gold-lg": "0 0 56px rgba(245,158,11,0.55), 0 8px 32px rgba(0,0,0,0.5)",
        glass:     "0 8px 32px rgba(0,0,0,0.35)",
      },
    },
  },
  plugins: [],
};

export default config;
