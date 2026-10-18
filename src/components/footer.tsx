import { content } from "@/content";

export function Footer({ version }: { version: string }) {
  return (
    <footer className="app-footer">
      <div className="app-footer-left">
        <span>{content.footer.brand}</span>
        <span className="app-footer-dot" aria-hidden="true">
          ·
        </span>
        <span>{content.footer.tagline}</span>
      </div>
      <div className="app-footer-right">
        <span className="app-footer-version">v{version}</span>
        <span className="app-footer-dot" aria-hidden="true">
          ·
        </span>
        <a
          className="app-footer-link"
          href={content.footer.creditUrl}
          target="_blank"
          rel="noopener noreferrer"
        >
          {content.footer.creditLabel}
        </a>
      </div>
    </footer>
  );
}
