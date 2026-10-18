export const content = {
  meta: {
    title: "Pofis — Mesaiye biraz Pofi.",
    description: "Kişisel mesai takibi. Mesaiye biraz Pofi.",
    url: "https://pofis.app",
    locale: "tr_TR",
    keywords: [
      "pofis",
      "pofi",
      "mesai takibi",
      "pdks",
      "mesaiye biraz pofi",
      "çalışma süresi",
      "mertcreates",
    ],
  },
  brand: {
    name: "Pofis",
    wordmark: "pofis",
    tagline: "Mesaiye biraz Pofi.",
  },
  install: {
    platforms: [
      { id: "macos", label: "macOS", command: "pofis=$(curl -fsSL https://pofis.app/install.sh) && /bin/bash -c \"$pofis\" --" },
      { id: "windows", label: "Windows PowerShell", command: "irm https://pofis.app/install.ps1 | iex" },
    ],
    copySuccessMessage: "Kopyalandı",
    copyAriaLabel: "Komutu kopyala",
    copyErrorMessage: "Kopyalanamadı. Komutu seçip elle kopyalayabilirsin.",
  },
  footer: {
    brand: "Pofis",
    tagline: "Mesaiye biraz Pofi.",
    creditLabel: "mertcreates.",
    creditUrl: "https://mertcreates.com",
  },
  theme: {
    toggleAriaLabel: "Tema değiştir",
  },
} as const;

export type Content = typeof content;
