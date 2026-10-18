"use client";

import { useState } from "react";
import { ArrowRight } from "lucide-react";
import { content } from "@/content";
import { ThemeToggle } from "@/components/theme-toggle";
import { Footer } from "@/components/footer";

export default function NotFound() {
  const [revealed, setRevealed] = useState(false);

  return (
    <>
      <header className="page-header">
        <a className="wordmark" href="/" aria-label={content.brand.name}>
          <img src="/pofi-mark-256.webp" width="30" height="30" alt="" />
          <span>{content.brand.wordmark}<span className="brand-dot">.</span></span>
        </a>
        <ThemeToggle />
      </header>
      <main className="not-found-container">
        <section className="not-found-hero" aria-labelledby="not-found-title">
          <div className="not-found-message">
            <h1 id="not-found-title">{content.notFound.title}</h1>
            <p>{content.notFound.help}</p>
            <a className="not-found-return" href="/">
              {content.notFound.returnLabel}<ArrowRight size={16} aria-hidden="true" />
            </a>
            {revealed && <p role="status">{content.notFound.pofiNote}</p>}
          </div>
          <button
            type="button"
            className="not-found-art"
            aria-label="Pofi"
            onClick={() => setRevealed(true)}
          >
            <img src="/pofi-tired.webp" width="320" height="320" alt="" />
          </button>
        </section>
      </main>
      <Footer />
    </>
  );
}
