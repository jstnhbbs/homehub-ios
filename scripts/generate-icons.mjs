import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const source = path.join(root, "public/icon.svg");
const iconsDir = path.join(root, "public/icons");
const appDir = path.join(root, "src/app");

const sizes = [16, 32, 48, 72, 96, 120, 128, 144, 152, 180, 192, 384, 512];

const svg = await readFile(source);
await mkdir(iconsDir, { recursive: true });

for (const size of sizes) {
  const output = path.join(iconsDir, `icon-${size}.png`);
  await sharp(svg, { density: Math.max(72, Math.ceil((size / 512) * 300)) })
    .resize(size, size)
    .png()
    .toFile(output);
}

await sharp(svg, { density: 300 })
  .resize(180, 180)
  .png()
  .toFile(path.join(iconsDir, "apple-touch-icon.png"));

await writeFile(path.join(appDir, "icon.png"), await sharp(svg).resize(32, 32).png().toBuffer());
await writeFile(
  path.join(appDir, "apple-icon.png"),
  await sharp(svg).resize(180, 180).png().toBuffer(),
);

console.log(`Generated ${sizes.length + 1} icons in public/icons/`);
console.log("Updated src/app/icon.png and src/app/apple-icon.png");
