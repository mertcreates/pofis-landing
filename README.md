# Pofis — landing ve dağıtım

Bu bağımsız depo pofis.app statik sitesini, Windows kurulum betiğini ve public sürüm manifestlerini içerir. Ana Pofis uygulamasının kaynakları private depoda kalır. Uygulama ZIP'leri Git geçmişine eklenmez; bu deponun GitHub Releases bölümünde sunulur.

## Yerel geliştirme

Bun 1.4.3 ile:

```powershell
bun install --frozen-lockfile
bun run dev
bun run typecheck
bun run build
```

Geliştirme adresi http://localhost:3001, yayın çıktısı `out/`. Site Next.js static export kullanır; sunucu, Pages Functions veya Workers gerekmez. `next start` bu çıktı için kullanılmaz.

`build` önce dağıtım girdilerini, sonra üretilen statik dosyaları doğrular. Manifest eksik/geçersizse, paket adresi bu GitHub deposuna ait değilse, ZIP/EXE/özel dosya yanlışlıkla siteye konmuşsa veya Pages dosya sınırı aşılırsa durur. Bu yerel kontrol, GitHub paketinin gerçekten yayımlandığını kanıtlamaz.

## Dağıtım dosyalarını hazırlama

Ana private Pofis projesinde paket ve release üretildikten sonra:

```powershell
bun run desktop:site
```

Varsayılan hedef yan yana duran `../pofis-landing` projesidir; farklı konum için `--site <klasör>` kullanılabilir. Hedef repository.url bu deponun package.json dosyasından okunur: `mertcreates/pofis-landing`.

Araç gerçek ZIP'in boyutunu ve SHA-256 değerini doğrular; yalnız ilgili `public/releases/<hedef>/latest.json` manifestini ve Windows'ta `public/install.ps1` dosyasını günceller. Installer'ın tek kaynak sahibi ana projedir; public kopyası burada yayımlanır. Paket veya private kaynak kopyalanmaz. Footer sürümü Windows manifestinden okunur. macOS ortak manifest yoluna hazırdır; macOS installer ve gerçek cihaz kabulü bekler.

## İlk yayın ve sonraki güncellemeler

Aşağıdaki dış işlemler ayrıca yayın yetkisiyle gerçekleştirilir. Bu hazırlık onları otomatik yapmaz.

1. GitHub'da `mertcreates/pofis-landing` public deposunu oluştur; bu klasörün incelenmiş dosyalarını gönder. Ana uygulama reposunu bağlama veya görünürlüğünü değiştirme.
2. Her sürümde önce GitHub Releases üzerinde `v<sürüm>` etiketli bir draft hazırla. Ana projenin `desktop:site` çıktısında yazan ZIP'i asset olarak ekle. Örneğin `v1.0.0` → `Pofis-1.0.0-win32-x64.zip`. Draft'ı doğrulayıp yayımla; anonim oturumdan paketin indirilebildiğini kontrol et.
3. Ana projede `desktop:site` çalıştır; burada `bun run typecheck` ve `bun run build` çalıştır. Installer/manifest değişikliklerini incele.
4. Yeni manifesti taşıyan site değişikliklerini ancak paket yayımlandıktan sonra gönder. Cloudflare aynı deployment içinde siteyi, installer'ı ve manifesti etkinleştirir. Manifesti paketten önce yayımlama.
5. Yayın sonrasında aşağıdaki HTTPS kabulünü yap. Aynı sürümün ZIP'ini değiştirme; yeni içerik için yeni sürüm üret. Önceki release asset'lerini güncelleme/geri dönüş için koru.

GitHub'ın otomatik Source code ZIP/TAR dosyaları yalnız bu landing deposunu içerir. Uygulama paketinin içindeki JavaScript incelenebilir; private repo, dağıtılmış kodun okunamazlığı anlamına gelmez.

## Cloudflare Pages ayarları

| Alan | Değer |
| --- | --- |
| Git deposu | mertcreates/pofis-landing |
| Production branch | main |
| Framework | Next.js (Static HTML Export) |
| Root directory | Depo kökü |
| Build command | bun install --frozen-lockfile && bun run build |
| Build output directory | out |
| Build image | v3 |
| BUN_VERSION | 1.4.3 |
| NODE_VERSION | 22.16.0 |
| SKIP_DEPENDENCY_INSTALL | 1 |

Ortam değişkenlerini production ve preview için tanımla. GitHub entegrasyonuna yalnız bu public depo için erişim ver; private uygulama deposu veya PDKS sırları gerekmez. Wrangler, Cloudflare API token'ı ve GitHub Actions bağımlılığı eklenmedi.

`pofis.app` adresini Pages → Custom domains üzerinden bağla. Apex domain için Cloudflare zone ve Cloudflare nameserver'ları gerekir. DNS taşınacaksa mevcut MX/TXT ve diğer kayıtları koruyarak ayrı onayla ilerle. Alan adı satın almak veya kayıt firmasını değiştirmek gerekmez. Bu dosyalar DNS'i değiştirmez.

`public/_headers` installer ve manifestlere `Cache-Control: no-store` uygular. Bu yolları örten bir Cache Everything/Edge TTL kuralı ekleme. Büyük ZIP'ler Pages'e yüklenmez; Pages tek dosya sınırı 25 MiB'dir.

## Yayın sonrası HTTPS kabulü

1. `https://pofis.app/` ve `/kurulum/` sayfalarını, Windows komutunu ve kopyalama düğmesini kontrol et.
2. `https://pofis.app/install.ps1` düz metin, `https://pofis.app/releases/windows/latest.json` JSON dönmeli; ikisinde de `Cache-Control: no-store` bulunmalı. HTML hata sayfası kabul edilmez.
3. Public manifestteki ZIP'i anonim indir; boyutunu ve SHA-256 değerini karşılaştır. Yayıncı hesabına giriş veya token gerekmemeli.
4. Windows'ta aşağıdaki gerçek komutla kurulum → otomatik açılış → simgeden açılış → aynı komutla güncel sürüm kontrolünü tamamla. Yeni sürümde veri koruma ve geri dönüşü doğrula.

```powershell
& ([scriptblock]::Create((irm https://pofis.app/install.ps1).TrimStart([char]0xFEFF)))
```

Bu komut hosting ve paket yayımlandıktan sonra kullanılabilir. Şu anda yerel hazırlık, canlı HTTPS kabulünün yerine geçmez.

## Kaynaklar

- [Cloudflare Pages build ayarları](https://developers.cloudflare.com/pages/configuration/build-configuration/)
- [Build image ve runtime sürümleri](https://developers.cloudflare.com/pages/configuration/build-image/)
- [Özel HTTP başlıkları](https://developers.cloudflare.com/pages/configuration/headers/)
- [Custom domain ve apex DNS koşulları](https://developers.cloudflare.com/pages/configuration/custom-domains/)
- [Pages sınırları](https://developers.cloudflare.com/pages/platform/limits/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
