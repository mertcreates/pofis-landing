import release from "../../public/releases/windows/latest.json";
import { content } from "@/content";
import { ThemeToggle } from "@/components/theme-toggle";
import { InstallCard } from "@/components/install-card";
import { Footer } from "@/components/footer";

export default function LandingPage() {
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

          <h1 className="brand-title">{content.brand.name}</h1>
          <p className="brand-slogan">{content.brand.tagline}</p>

          <InstallCard />
        </div>
      </main>

      <Footer version={release.version} />
    </>
  );
}
