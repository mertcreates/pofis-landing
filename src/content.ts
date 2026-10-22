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
    description: "Günlük mesaini takip et, haftanı planla. Pofi de gününe eşlik etsin.",
  },
  install: {
    platforms: [
      {
        id: "unix", label: "macOS / Ubuntu",
        command: "curl -fsSL https://pofis.app/install.sh | bash",
        instructions: "Terminal’i aç, komutu yapıştır ve Enter’a bas.",
      },
      {
        id: "windows", label: "Windows PowerShell",
        command: "irm https://pofis.app/install.ps1 | iex",
        instructions: "PowerShell’i aç, komutu yapıştır ve Enter’a bas.",
      },
    ],
    copySuccessMessage: "Kopyalandı",
    copyAriaLabel: "Komutu kopyala",
    copyErrorMessage: "Kopyalanamadı. Komutu seçip elle kopyalayabilirsin.",
  },
  installHelp: {
    title: "Kurulum hakkında",
    items: [
      {
        question: "Giriş için hangi hesabı kullanacağım?",
        answer: "PDKS’de kullandığın kullanıcı adı ve parolayla giriş yapabilirsin. PDKS’ye ulaşabilmek için kurum ağına ya da VPN’e bağlı olman gerekiyor.",
      },
      {
        question: "Kurulum bitince ne yapacağım?",
        answer: "Pofis kendiliğinden açılır. Giriş yaptıktan sonra mesai kayıtlarını görebilirsin.",
      },
      {
        question: "Nasıl güncelleyeceğim?",
        answer: "Yeni bir sürüm varsa Pofis açıldığında “Yeni sürüm var” düğmesini görürsün. Oradaki komutu kopyalayıp ilk kurulumdaki gibi çalıştırabilirsin.",
      },
    ],
  },
  footer: {
    brand: "Pofis",
    tagline: "Mesaiye biraz Pofi",
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
