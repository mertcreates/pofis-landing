const { readFile, readdir, stat } = require("node:fs/promises");
const { resolve, join } = require("node:path");

async function verify(root = resolve(__dirname, ".."), output = false) {
  const pkg = JSON.parse(await readFile(join(root, "package.json"), "utf8"));
  const repository = pkg.repository?.url?.match(/^https:\/\/github\.com\/([\w-]+\/[\w.-]+)\.git$/)?.[1];
  if (!repository) throw new Error("GitHub repository.url tanımlanmalı.");
  const directory = join(root, output ? "out" : "public");
  const versions = new Set();
  for (const [target, platform, arch] of [
    ["windows", "win32", "x64"],
    ["macos/arm64", "darwin", "arm64"],
    ["macos/x64", "darwin", "x64"],
  ]) {
    let raw;
    try {
      raw = await readFile(join(directory, "releases", target, "latest.json"), "utf8");
    } catch (error) {
      if (error.code === "ENOENT") continue;
      throw error;
    }
    const manifest = JSON.parse(raw);
    const name = "Pofis-" + manifest.version + "-" + platform + "-" + arch + ".zip";
    if (manifest.schemaVersion !== 1 || manifest.platform !== platform || manifest.arch !== arch ||
        !/^\d+\.\d+\.\d+$/.test(manifest.version) || !Number.isSafeInteger(manifest.size) || manifest.size <= 0 ||
        !/^[a-f0-9]{64}$/.test(manifest.sha256) ||
        manifest.url !== "https://github.com/" + repository + "/releases/download/v" + manifest.version + "/" + name) {
      throw new Error(target + " manifesti veya GitHub paket adresi geçersiz. Ana projede desktop:site çalıştır.");
    }
    versions.add(manifest.version);
  }
  if (versions.size > 1) throw new Error("Platformların sürümleri eşleşmiyor.");
  const installer = await readFile(join(directory, "install.ps1"), "utf8");
  if (!installer.includes("https://pofis.app/releases/windows/latest.json")) throw new Error("Kurulum betiğinin varsayılan adresi geçersiz.");
  const macInstaller = await readFile(join(directory, "install.sh"), "utf8");
  if (!macInstaller.startsWith("#!/bin/bash\n") || !macInstaller.includes("https://pofis.app/releases/macos/$arch/latest.json")) {
    throw new Error("macOS kurulum betiğinin içeriği geçersiz.");
  }
  let count = 0;
  async function inspect(path) {
    for (const entry of await readdir(path, { withFileTypes: true })) {
      const file = join(path, entry.name);
      if (entry.isSymbolicLink() || /^(?:\.env.*|\.git|node_modules)$/.test(entry.name) || /\.(?:zip|exe|asar)$/.test(entry.name)) {
        throw new Error("Site çıktısına dağıtım paketi, bağlantı veya özel dosya konulmamalı: " + file);
      }
      if (entry.isDirectory()) await inspect(file);
      else {
        if ((await stat(file)).size > 25 * 1024 * 1024) throw new Error("Statik dosya 25 MiB sınırı aşıldı: " + file);
        count++;
      }
    }
  }
  await inspect(directory);
  if (count > 20000) throw new Error("Statik çıktı dosya sayısı sınırı aşıldı.");
  if (output) {
    for (const path of ["index.html", "_headers"]) await stat(join(directory, path));
  }
  console.log((output ? "Statik çıktı" : "Dağıtım girdileri") + " doğrulandı: " + ([...versions][0] || "henüz paket yayımlanmadı") + ", " + count + " dosya.");
}
if (require.main === module) verify(undefined, process.argv.includes("--output")).catch(error => {
  console.error("Yayın hazırlığı başarısız: " + error.message); process.exitCode = 1;
});
module.exports = { verify };
