import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const composedSvgPath = path.join(root, "public/icon.svg");
const iconsDir = path.join(root, "public/icons");
const appDir = path.join(root, "src/app");
const publicIconPartsDir = path.join(root, "public/icon");
const loadingIconDir = path.join(
  root,
  "ios/HomeHub/Assets.xcassets/LoadingIcon.imageset",
);
const iosIconDir = path.join(
  root,
  "ios/HomeHub/Assets.xcassets/HomeHub.appiconset",
);
const iconComposerDir = path.join(root, "ios/Beacon.icon");
const iosAssetsDir = path.join(root, "ios/HomeHub/Assets.xcassets");
const iconCanvasSize = 1024;
const iconCornerRadius = 0;
const appIconPreviews = [
  ["Sage", "Beacon"],
  ["Ocean", "BeaconOcean"],
  ["Clay", "BeaconClay"],
  ["Plum", "BeaconPlum"],
  ["Slate", "BeaconSlate"],
  ["Rosewood", "BeaconRosewood"],
  ["Teal", "BeaconTeal"],
  ["Indigo", "BeaconIndigo"],
  ["Rose", "BeaconRose"],
  ["Ochre", "BeaconOchre"],
];

const webSizes = [16, 32, 48, 72, 96, 120, 128, 144, 152, 180, 192, 384, 512];

const iosSizes = [
  { filename: "Icon-iPhone-20@2x.png", size: 40 },
  { filename: "Icon-iPhone-20@3x.png", size: 60 },
  { filename: "Icon-iPhone-29@2x.png", size: 58 },
  { filename: "Icon-iPhone-29@3x.png", size: 87 },
  { filename: "Icon-iPhone-40@2x.png", size: 80 },
  { filename: "Icon-iPhone-40@3x.png", size: 120 },
  { filename: "Icon-iPhone-60@2x.png", size: 120 },
  { filename: "Icon-iPhone-60@3x.png", size: 180 },
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
      filename: "Icon-iPhone-20@2x.png",
      idiom: "iphone",
      scale: "2x",
      size: "20x20",
    },
    {
      filename: "Icon-iPhone-20@3x.png",
      idiom: "iphone",
      scale: "3x",
      size: "20x20",
    },
    {
      filename: "Icon-iPhone-29@2x.png",
      idiom: "iphone",
      scale: "2x",
      size: "29x29",
    },
    {
      filename: "Icon-iPhone-29@3x.png",
      idiom: "iphone",
      scale: "3x",
      size: "29x29",
    },
    {
      filename: "Icon-iPhone-40@2x.png",
      idiom: "iphone",
      scale: "2x",
      size: "40x40",
    },
    {
      filename: "Icon-iPhone-40@3x.png",
      idiom: "iphone",
      scale: "3x",
      size: "40x40",
    },
    {
      filename: "Icon-iPhone-60@2x.png",
      idiom: "iphone",
      scale: "2x",
      size: "60x60",
    },
    {
      filename: "Icon-iPhone-60@3x.png",
      idiom: "iphone",
      scale: "3x",
      size: "60x60",
    },
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

const loadingIconContents = {
  images: [
    {
      filename: "LoadingIcon.png",
      idiom: "universal",
      scale: "1x",
    },
    {
      idiom: "universal",
      scale: "2x",
    },
    {
      idiom: "universal",
      scale: "3x",
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

function parseColor(value, fallback) {
  if (!value || value === "none") {
    return fallback;
  }

  const [space, components] = value.split(":");
  if (!components || !["srgb", "display-p3", "extended-srgb"].includes(space)) {
    return fallback;
  }

  const [red, green, blue, alpha = "1"] = components
    .split(",")
    .map((part) => Number(part));

  if ([red, green, blue, alpha].some((channel) => Number.isNaN(channel))) {
    return fallback;
  }

  const toRgb = (channel) =>
    Math.round(Math.max(0, Math.min(1, channel)) * 255);

  if (alpha < 1) {
    return `rgba(${toRgb(red)}, ${toRgb(green)}, ${toRgb(blue)}, ${alpha})`;
  }

  return `#${[toRgb(red), toRgb(green), toRgb(blue)]
    .map((channel) => channel.toString(16).padStart(2, "0"))
    .join("")}`;
}

function layerTransform(layer) {
  const position = layer.position ?? {};
  const scale = position.scale ?? 1;
  const [x = 0, y = 0] = position["translation-in-points"] ?? [];

  return [
    `translate(${iconCanvasSize / 2} ${iconCanvasSize / 2})`,
    `translate(${x} ${y})`,
    `scale(${scale})`,
    `translate(${-iconCanvasSize / 2} ${-iconCanvasSize / 2})`,
  ].join(" ");
}

function layerFill(layer) {
  if (layer.fill?.solid) {
    return parseColor(layer.fill.solid, null);
  }
  const specialization = layer["fill-specializations"]?.find(
    (item) => !item.appearance && item.value && item.value !== "none",
  );
  return specialization?.value?.solid
    ? parseColor(specialization.value.solid, null)
    : null;
}

async function loadIconLayers(directory = iconComposerDir) {
  const iconDocument = JSON.parse(
    await readFile(path.join(directory, "icon.json"), "utf8"),
  );
  const background = parseColor(iconDocument.fill?.solid, "#f7f3e9");
  const iconGroup = iconDocument.groups?.[0];

  if (!iconGroup?.layers?.length) {
    throw new Error("Missing layers in ios/Beacon.icon/icon.json");
  }

  const visibleLayerSpecs = iconGroup.layers
    .filter((layer) => !layer.hidden)
    .reverse();

  const layers = await Promise.all(
    visibleLayerSpecs.map(async (layer) => {
      const filename = layer["image-name"];
      if (!filename) {
        throw new Error(`Missing image-name for layer ${layer.name ?? ""}`);
      }

      const filePath = path.join(directory, "Assets", filename);
      const svg = await readFile(filePath, "utf8");
      const fill = layerFill(layer);
      const body = extractSvgBody(svg);
      return {
        filename,
        name: layer.name ?? filename,
        rawSvg: svg,
        body: fill
          ? body.replaceAll(/fill="[^"]+"/g, `fill="${fill}"`)
          : body,
        transform: layerTransform(layer),
      };
    }),
  );

  return { background, layers };
}

function composeSvg({ background, layers }) {
  const layerMarkup = layers
    .map(
      (layer) =>
        `<g id="${layer.name}" transform="${layer.transform}">\n    ${layer.body}\n  </g>`,
    )
    .join("\n  ");

  return [
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${iconCanvasSize} ${iconCanvasSize}">`,
    `  <rect width="${iconCanvasSize}" height="${iconCanvasSize}" rx="${iconCornerRadius}" fill="${background}"/>`,
    `  ${layerMarkup}`,
    "</svg>",
    "",
  ].join("\n");
}

function wrapLayerSvg(layer) {
  return [
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${iconCanvasSize} ${iconCanvasSize}">`,
    `  <g transform="${layer.transform}">`,
    `    ${layer.body}`,
    "  </g>",
    "</svg>",
    "",
  ].join("\n");
}

function backgroundSvg(background) {
  return [
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${iconCanvasSize} ${iconCanvasSize}">`,
    `  <rect width="${iconCanvasSize}" height="${iconCanvasSize}" rx="${iconCornerRadius}" fill="${background}"/>`,
    "</svg>",
    "",
  ].join("\n");
}

async function writePublicIconLayers({ background, layers }) {
  await mkdir(publicIconPartsDir, { recursive: true });
  await writeFile(path.join(publicIconPartsDir, "background.svg"), backgroundSvg(background));

  for (const layer of layers) {
    await writeFile(path.join(publicIconPartsDir, layer.filename), wrapLayerSvg(layer));
  }
}

async function composeRaster(size, composedSvg) {
  return renderSize(composedSvg, size).png();
}

function renderSize(svg, size) {
  const input = Buffer.isBuffer(svg) ? svg : Buffer.from(svg);
  return sharp(input, {
    density: Math.max(72, Math.ceil((size / iconCanvasSize) * 300)),
  }).resize(size, size);
}

function createIco(images) {
  const headerSize = 6;
  const directorySize = images.length * 16;
  let imageOffset = headerSize + directorySize;
  const header = Buffer.alloc(headerSize);
  const directories = [];

  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(images.length, 4);

  for (const image of images) {
    const directory = Buffer.alloc(16);
    directory.writeUInt8(image.size >= 256 ? 0 : image.size, 0);
    directory.writeUInt8(image.size >= 256 ? 0 : image.size, 1);
    directory.writeUInt8(0, 2);
    directory.writeUInt8(0, 3);
    directory.writeUInt16LE(1, 4);
    directory.writeUInt16LE(32, 6);
    directory.writeUInt32LE(image.buffer.length, 8);
    directory.writeUInt32LE(imageOffset, 12);
    directories.push(directory);
    imageOffset += image.buffer.length;
  }

  return Buffer.concat([
    header,
    ...directories,
    ...images.map((image) => image.buffer),
  ]);
}

async function generateAppIconPreviews() {
  for (const [palette, iconName] of appIconPreviews) {
    const imageSetName = `AppIcon${palette}Preview.imageset`;
    const imageName = `AppIcon${palette}Preview.png`;
    const imageSetDirectory = path.join(iosAssetsDir, imageSetName);
    const icon = await loadIconLayers(path.join(root, `ios/${iconName}.icon`));

    await mkdir(imageSetDirectory, { recursive: true });
    await (await composeRaster(256, composeSvg(icon))).toFile(
      path.join(imageSetDirectory, imageName),
    );
    await writeFile(
      path.join(imageSetDirectory, "Contents.json"),
      `${JSON.stringify(
        {
          images: [
            {
              filename: imageName,
              idiom: "universal",
              scale: "1x",
            },
          ],
          info: {
            author: "xcode",
            version: 1,
          },
        },
        null,
        2,
      )}\n`,
    );
  }
}

if (process.argv.includes("--app-icon-previews-only")) {
  await generateAppIconPreviews();
  console.log(`Generated ${appIconPreviews.length} app icon previews.`);
  process.exit(0);
}

const icon = await loadIconLayers();
const composedSvg = composeSvg(icon);

await writeFile(composedSvgPath, composedSvg);
await writePublicIconLayers(icon);
await mkdir(iconsDir, { recursive: true });
await mkdir(iosIconDir, { recursive: true });
await mkdir(loadingIconDir, { recursive: true });

for (const size of webSizes) {
  const output = path.join(iconsDir, `icon-${size}.png`);
  await (await composeRaster(size, composedSvg)).toFile(output);
}

await (await composeRaster(180, composedSvg)).toFile(
  path.join(iconsDir, "apple-touch-icon.png"),
);

await writeFile(
  path.join(appDir, "icon.png"),
  await (await composeRaster(32, composedSvg)).toBuffer(),
);
await writeFile(
  path.join(appDir, "apple-icon.png"),
  await (await composeRaster(180, composedSvg)).toBuffer(),
);
await writeFile(
  path.join(appDir, "favicon.ico"),
  createIco([
    {
      size: 16,
      buffer: await (await composeRaster(16, composedSvg)).toBuffer(),
    },
    {
      size: 32,
      buffer: await (await composeRaster(32, composedSvg)).toBuffer(),
    },
  ]),
);

for (const { filename, size } of iosSizes) {
  await (await composeRaster(size, composedSvg)).toFile(
    path.join(iosIconDir, filename),
  );
}

await (await composeRaster(1024, composedSvg)).toFile(
  path.join(loadingIconDir, "LoadingIcon.png"),
);

await writeFile(
  path.join(iosIconDir, "Contents.json"),
  `${JSON.stringify(iosContents, null, 2)}\n`,
);
await writeFile(
  path.join(loadingIconDir, "Contents.json"),
  `${JSON.stringify(loadingIconContents, null, 2)}\n`,
);
// The picker previews are not made here: they are renders from Icon Composer (ictool, see AGENTS.md), and
// this script's flat renderer would overwrite them. `--app-icon-previews-only` still makes the flat ones.

console.log(
  `Composed public/icon.svg from ${icon.layers.length} visible layers in ios/Beacon.icon/`,
);
console.log("Synced transformed source SVGs to public/icon/");
console.log(`Generated ${webSizes.length + 1} icons in public/icons/`);
console.log("Updated src/app/icon.png and src/app/apple-icon.png");
console.log("Updated src/app/favicon.ico");
console.log(
  `Updated iOS HomeHub.appiconset fallback PNGs (${iosSizes.length} files)`,
);
console.log("Updated iOS LoadingIcon.imageset");
