export const content = {
  meta: {
    title: "Pofis — Mesaiye biraz Pofi",
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
    tagline: "Mesaiye biraz Pofi",
  },
  install: {
    platforms: [
      { id: "macos", label: "macOS", command: "curl -fsSL https://pofis.app/install.sh | bash" },
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
  notFound: {
    title: "Sayfa bulunamadı",
    help: "Adresi kontrol et veya ana sayfaya dön.",
    returnLabel: "Ana sayfaya dön",
    pofiNote: "Ben de yanlış kapıyı açmışım.",
  },
  theme: {
    switchToLight: "Açık temaya geç",
    switchToDark: "Koyu temaya geç",
  },
} as const;

export type Content = typeof content;
