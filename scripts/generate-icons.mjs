import { copyFile, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const iconPartsDir = path.join(root, "public/icon");
const composedSvgPath = path.join(root, "public/icon.svg");
const iconsDir = path.join(root, "public/icons");
const appDir = path.join(root, "src/app");
const iosIconDir = path.join(
  root,
  "ios/HomeHub/Assets.xcassets/HomeHub.appiconset",
);
const iconComposerAssetsDir = path.join(root, "ios/HomeHub.icon/Assets");

/** Layer order for the Home Hub app icon. */
const ICON_LAYER_FILES = [
  "background.svg",
  "house.svg",
  "door.svg",
  "sun.svg",
];

const webSizes = [16, 32, 48, 72, 96, 120, 128, 144, 152, 180, 192, 384, 512];

const iosSizes = [
  { filename: "Icon-20.png", size: 20 },
  { filename: "Icon-20@2x.png", size: 40 },
  { filename: "Icon-29.png", size: 29 },
  { filename: "Icon-29@2x.png", size: 58 },
  { filename: "Icon-40.png", size: 40 },
  { filename: "Icon-40@2x.png", size: 80 },
  { filename: "Icon-76.png", size: 76 },
  { filename: "Icon-76@2x.png", size: 152 },
  { filename: "Icon-83.5@2x.png", size: 167 },
  { filename: "Icon-1024.png", size: 1024 },
];

const iosContents = {
  images: [
    {
      filename: "Icon-20@2x.png",
      idiom: "ipad",
      scale: "2x",
      size: "20x20",
    },
    {
      filename: "Icon-20.png",
      idiom: "ipad",
      scale: "1x",
      size: "20x20",
    },
    {
      filename: "Icon-29@2x.png",
      idiom: "ipad",
      scale: "2x",
      size: "29x29",
    },
    {
      filename: "Icon-29.png",
      idiom: "ipad",
      scale: "1x",
      size: "29x29",
    },
    {
      filename: "Icon-40@2x.png",
      idiom: "ipad",
      scale: "2x",
      size: "40x40",
    },
    {
      filename: "Icon-40.png",
      idiom: "ipad",
      scale: "1x",
      size: "40x40",
    },
    {
      filename: "Icon-76@2x.png",
      idiom: "ipad",
      scale: "2x",
      size: "76x76",
    },
    {
      filename: "Icon-76.png",
      idiom: "ipad",
      scale: "1x",
      size: "76x76",
    },
    {
      filename: "Icon-83.5@2x.png",
      idiom: "ipad",
      scale: "2x",
      size: "83.5x83.5",
    },
    {
      filename: "Icon-1024.png",
      idiom: "ios-marketing",
      scale: "1x",
      size: "1024x1024",
    },
  ],
  info: {
    author: "xcode",
    version: 1,
  },
};

function extractSvgBody(svg) {
  const match = svg.match(/<svg[^>]*>([\s\S]*?)<\/svg>/i);
  if (!match) {
    throw new Error("Invalid SVG layer.");
  }
  return match[1].trim();
}

async function loadIconLayers() {
  const available = new Set(await readdir(iconPartsDir));
  const missing = ICON_LAYER_FILES.filter((file) => !available.has(file));
  if (missing.length) {
    throw new Error(`Missing icon layer(s) in public/icon/: ${missing.join(", ")}`);
  }

  const layers = [];
  for (const filename of ICON_LAYER_FILES) {
    const filePath = path.join(iconPartsDir, filename);
    const svg = await readFile(filePath, "utf8");
    layers.push({ filename, svg, body: extractSvgBody(svg) });
  }
  return layers;
}

function composeSvg(layers) {
  const body = layers.map((layer) => layer.body).join("\n  ");
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">\n  ${body}\n</svg>\n`;
}

async function composeRaster(size, layers) {
  const composites = await Promise.all(
    layers.map(async (layer) => ({
      input: await renderSize(layer.svg, size).toBuffer(),
      top: 0,
      left: 0,
    })),
  );

  return sharp({
    create: {
      width: size,
      height: size,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite(composites)
    .png();
}

function renderSize(svg, size) {
  const input = Buffer.isBuffer(svg) ? svg : Buffer.from(svg);
  return sharp(input, {
    density: Math.max(72, Math.ceil((size / 512) * 300)),
  }).resize(size, size);
}

const layers = await loadIconLayers();
const composedSvg = composeSvg(layers);

await writeFile(composedSvgPath, composedSvg);
await mkdir(iconsDir, { recursive: true });
await mkdir(iosIconDir, { recursive: true });
await mkdir(iconComposerAssetsDir, { recursive: true });

for (const filename of ICON_LAYER_FILES) {
  await copyFile(
    path.join(iconPartsDir, filename),
    path.join(iconComposerAssetsDir, filename),
  );
}

for (const size of webSizes) {
  const output = path.join(iconsDir, `icon-${size}.png`);
  await (await composeRaster(size, layers)).toFile(output);
}

await (await composeRaster(180, layers)).toFile(
  path.join(iconsDir, "apple-touch-icon.png"),
);

await writeFile(
  path.join(appDir, "icon.png"),
  await (await composeRaster(32, layers)).toBuffer(),
);
await writeFile(
  path.join(appDir, "apple-icon.png"),
  await (await composeRaster(180, layers)).toBuffer(),
);

for (const { filename, size } of iosSizes) {
  await (await composeRaster(size, layers)).toFile(
    path.join(iosIconDir, filename),
  );
}

await writeFile(
  path.join(iosIconDir, "Contents.json"),
  `${JSON.stringify(iosContents, null, 2)}\n`,
);

console.log(
  `Composed public/icon.svg from ${layers.length} layers in public/icon/`,
);
console.log(`Synced Icon Composer assets to ios/HomeHub.icon/Assets/`);
console.log(`Generated ${webSizes.length + 1} icons in public/icons/`);
console.log("Updated src/app/icon.png and src/app/apple-icon.png");
console.log(
  `Updated iOS HomeHub.appiconset fallback PNGs (${iosSizes.length} files)`,
);
