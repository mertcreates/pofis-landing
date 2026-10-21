import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ChevronDown } from "lucide-react";
import { content } from "@/content";
import { ThemeToggle } from "@/components/theme-toggle";
import { InstallCard } from "@/components/install-card";
import { Footer } from "@/components/footer";

export default async function LandingPage() {
  let version: string | undefined;
  try {
    const raw = await readFile(join(process.cwd(), "public/releases/windows/latest.json"), "utf8");
    version = JSON.parse(raw).version;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }
  return (
    <>
      <header className="page-header">
        <a className="wordmark" href="/" aria-label="Pofis">
          <img src="/pofi-mark-256.webp" width="30" height="30" alt="" />
          <span>
            {content.brand.wordmark}
            <span className="brand-dot">.</span>
          </span>
        </a>
        <ThemeToggle />
      </header>

      <main className="hero-container">
        <div className="hero">
          <div className="pofi-image-wrap">
            <img
              className="pofi-img"
              src="/pofi-full.webp"
              alt={content.brand.name}
              width={120}
              height={156}
              fetchPriority="high"
            />
          </div>

          <h1 className="brand-title">{content.brand.tagline}</h1>
          <p className="brand-description">{content.brand.description}</p>

          <InstallCard />

          <details className="install-help">
            <summary>
              {content.installHelp.title}
              <ChevronDown size={16} aria-hidden="true" />
            </summary>
            <dl>
              {content.installHelp.items.map(item => (
                <div key={item.question}>
                  <dt>{item.question}</dt>
                  <dd>{item.answer}</dd>
                </div>
              ))}
            </dl>
          </details>
        </div>
      </main>

      <Footer version={version} />
    </>
  );
}
