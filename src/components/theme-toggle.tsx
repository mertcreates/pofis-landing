"use client";

import { useEffect, useState } from "react";
import { Sun, Moon } from "lucide-react";
import { content } from "@/content";

const THEME_STORAGE_KEY = "pofis:theme:v1";

export function ThemeToggle() {
  const [theme, setTheme] = useState<"light" | "dark" | null>(null);

  useEffect(() => {
    let saved: string | null = null;
    try {
      saved = localStorage.getItem(THEME_STORAGE_KEY);
    } catch {
      // Storage unavailable
    }

    const media = window.matchMedia("(prefers-color-scheme: dark)");
    if (saved === "light" || saved === "dark") {
      document.documentElement.dataset.theme = saved;
    }

    function syncTheme() {
      const explicit = document.documentElement.dataset.theme;
      setTheme(explicit === "light" || explicit === "dark"
        ? explicit
        : media.matches ? "dark" : "light");
    }

    syncTheme();
    media.addEventListener("change", syncTheme);
    return () => media.removeEventListener("change", syncTheme);
  }, []);

  function toggle() {
    const current = document.documentElement.dataset.theme
      ?? (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    const next = current === "dark" ? "light" : "dark";
    setTheme(next);
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(THEME_STORAGE_KEY, next);
    } catch {
      // Storage unavailable
    }
  }

  return (
    <button
      type="button"
      className="theme-toggle-btn"
      aria-label={theme === "dark" ? content.theme.switchToLight : content.theme.switchToDark}
      onClick={toggle}
    >
      {theme === "dark" ? (
        <Sun size={17} strokeWidth={1.8} />
      ) : (
        <Moon size={17} strokeWidth={1.8} />
      )}
    </button>
  );
}
