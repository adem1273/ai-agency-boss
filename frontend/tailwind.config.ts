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
