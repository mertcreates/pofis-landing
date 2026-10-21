"use client";

import { useEffect, useRef, useState, type KeyboardEvent } from "react";
import { Copy, Check } from "lucide-react";
import { content } from "@/content";

const platforms = content.install.platforms;

export function InstallCard() {
  const [active, setActive] = useState(0);
  const [copied, setCopied] = useState(false);
  const [copyFailed, setCopyFailed] = useState(false);
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);
  const platform = platforms[active];
  const copyRequest = useRef(0);
  const copyTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (/Windows/i.test(navigator.userAgent)) {
      setActive(platforms.findIndex(item => item.id === "windows"));
    }
  }, []);

  useEffect(() => () => {
    copyRequest.current += 1;
    if (copyTimer.current !== null) clearTimeout(copyTimer.current);
  }, []);

  function select(index: number) {
    copyRequest.current += 1;
    if (copyTimer.current !== null) clearTimeout(copyTimer.current);
    setActive(index);
    setCopied(false);
    setCopyFailed(false);
  }

  function handleKey(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    let next = index;
    if (event.key === "ArrowRight") next = (index + 1) % platforms.length;
    else if (event.key === "ArrowLeft") next = (index + platforms.length - 1) % platforms.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = platforms.length - 1;
    else return;
    event.preventDefault();
    select(next);
    tabs.current[next]?.focus();
  }

  async function handleCopy() {
    const request = ++copyRequest.current;
    if (copyTimer.current !== null) clearTimeout(copyTimer.current);
    setCopied(false);
    setCopyFailed(false);
    let success = false;
    try {
      await navigator.clipboard.writeText(platform.command);
      success = true;
    } catch {
      if (request !== copyRequest.current) return;
      const previousFocus = document.activeElement;
      const textArea = document.createElement("textarea");
      textArea.value = platform.command;
      textArea.className = "sr-only";
      document.body.appendChild(textArea);
      textArea.select();
      try { success = document.execCommand("copy"); }
      catch { /* Tarayıcı kopyalamayı engellerse elle seçim mesajı gösterilir. */ }
      finally {
        document.body.removeChild(textArea);
        if (previousFocus instanceof HTMLElement) previousFocus.focus();
      }
    }
    if (request !== copyRequest.current) return;
    setCopied(success);
    setCopyFailed(!success);
    if (success) {
      copyTimer.current = setTimeout(() => setCopied(false), 1600);
    }
  }

  return (
    <section className="install-section" aria-label="Kurulum">
      <div className="install-tabs" role="tablist" aria-label="İşletim sistemi">
        {platforms.map((item, index) => (
          <button key={item.id} type="button" role="tab" className="install-tab"
            id={"install-tab-" + item.id} aria-controls={"install-panel-" + item.id}
            aria-selected={active === index} tabIndex={active === index ? 0 : -1}
            ref={element => { tabs.current[index] = element; }}
            onClick={() => select(index)} onKeyDown={event => handleKey(event, index)}>
            {item.label}
          </button>
        ))}
      </div>
      <div className="install-panels">
      {platforms.map((item, index) => (
      <div key={item.id} className="install-card" role="tabpanel" tabIndex={active === index ? 0 : -1}
        aria-hidden={active !== index}
        id={"install-panel-" + item.id} aria-labelledby={"install-tab-" + item.id}>
          <div className="install-row">
            <code className="install-cmd">{item.command}</code>
            <button type="button" className={"copy-btn" + (copied ? " copied" : "")}
              aria-label={copied ? content.install.copySuccessMessage : content.install.copyAriaLabel}
              onClick={handleCopy} title={copied ? content.install.copySuccessMessage : content.install.copyAriaLabel}>
              {copied ? <Check size={16} strokeWidth={2.2} /> : <Copy size={16} strokeWidth={2} />}
            </button>
          </div>
      </div>
      ))}
      </div>
      <p className="install-instructions">{platform.instructions}</p>
      <p className={copyFailed ? "hint-text" : "sr-only"} role="status" aria-atomic="true">
        {copyFailed ? content.install.copyErrorMessage : copied ? content.install.copySuccessMessage : ""}
      </p>
    </section>
  );
}
