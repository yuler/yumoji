// 照片绘制与贴纸合成，按 StickerCompositor.swift 的步骤用 Canvas 实现：
// 主体 mask 膨胀出白边 -> 模糊再拉陡边缘 -> 填白 -> 叠上抠出的主体 -> 紧贴裁切。

const PHOTO_SIZE = 1024;
const MASK_THRESHOLD = 128; // SubjectMask.threshold

function newCanvas(w, h) {
  const c = document.createElement("canvas");
  c.width = Math.max(1, Math.round(w));
  c.height = Math.max(1, Math.round(h));
  return c;
}

function drawFoods(ctx, photo) {
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  photo.foods.forEach((f) => {
    ctx.font = `${f.size}px "Apple Color Emoji", "Noto Color Emoji", "Segoe UI Emoji", sans-serif`;
    ctx.fillText(f.emoji, PHOTO_SIZE / 2 + f.x, PHOTO_SIZE / 2 + f.y);
  });
}

/** 画出一张样例照片和它的主体 mask（只含食物）。 */
function renderPhoto(photo) {
  const canvas = newCanvas(PHOTO_SIZE, PHOTO_SIZE);
  const ctx = canvas.getContext("2d");
  const bg = ctx.createLinearGradient(0, 0, PHOTO_SIZE, PHOTO_SIZE);
  bg.addColorStop(0, photo.table[0]);
  bg.addColorStop(1, photo.table[1]);
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, PHOTO_SIZE, PHOTO_SIZE);
  ctx.fillStyle = "rgba(255,255,255,0.35)";
  ctx.beginPath();
  ctx.arc(512, 520, 430, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#fffaf2";
  ctx.beginPath();
  ctx.arc(512, 520, 370, 0, Math.PI * 2);
  ctx.fill();
  drawFoods(ctx, photo);

  const mask = newCanvas(PHOTO_SIZE, PHOTO_SIZE);
  drawFoods(mask.getContext("2d"), photo);
  return { canvas, mask, bounds: findBounds(mask) };
}

/** SubjectMask.findBounds：alpha 达到阈值的像素的外接框，没有主体时为 null。 */
function findBounds(mask) {
  const { width, height } = mask;
  const data = mask.getContext("2d").getImageData(0, 0, width, height).data;
  let minX = width, minY = height, maxX = -1, maxY = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] >= MASK_THRESHOLD) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  return { x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1 };
}

/** StickerCompositor.makeSticker：返回贴纸 canvas，透明背景。 */
function makeSticker(lifted, style) {
  const b = lifted.bounds;
  if (!b) return null;
  const longSide = Math.max(b.width, b.height);
  const border = Math.max(0, style.borderRatio) * longSide;
  const margin = Math.max(0, style.marginRatio) * longSide;
  const pad = Math.ceil(border + margin) + 1;
  const crop = { x: b.x - pad, y: b.y - pad, width: b.width + 2 * pad, height: b.height + 2 * pad };

  const subjectMask = newCanvas(crop.width, crop.height);
  subjectMask.getContext("2d").drawImage(lifted.mask, -crop.x, -crop.y);

  const out = newCanvas(crop.width, crop.height);
  const ctx = out.getContext("2d");
  if (border >= 0.5) {
    ctx.drawImage(borderMask(subjectMask, border, Math.max(0, style.edgeSmoothing) * border), 0, 0);
  }

  const subject = newCanvas(crop.width, crop.height);
  const sctx = subject.getContext("2d");
  sctx.drawImage(lifted.canvas, -crop.x, -crop.y);
  sctx.globalCompositeOperation = "destination-in";
  sctx.drawImage(subjectMask, 0, 0);
  ctx.drawImage(subject, 0, 0);
  return out;
}

/** 白色边框层：mask 膨胀 radius 像素，sigma 够大时模糊后再把边缘拉回约 1.5 px 宽。 */
function borderMask(mask, radius, sigma) {
  const w = mask.width, h = mask.height;
  const white = newCanvas(w, h);
  const wctx = white.getContext("2d");
  wctx.drawImage(mask, 0, 0);
  wctx.globalCompositeOperation = "source-in";
  wctx.fillStyle = "#fff";
  wctx.fillRect(0, 0, w, h);

  // CIMorphologyMaximum 的近似：在半径内的网格点上平移叠画
  const grown = newCanvas(w, h);
  const gctx = grown.getContext("2d");
  const step = Math.max(1, radius / 8);
  for (let dy = -radius; dy <= radius + 0.01; dy += step) {
    for (let dx = -radius; dx <= radius + 0.01; dx += step) {
      if (dx * dx + dy * dy <= radius * radius + 0.01) gctx.drawImage(white, dx, dy);
    }
  }
  if (sigma < 0.5) return grown;

  const blurred = newCanvas(w, h);
  const bctx = blurred.getContext("2d");
  bctx.filter = `blur(${sigma}px)`;
  bctx.drawImage(grown, 0, 0);
  bctx.filter = "none";

  const gain = Math.max(1, 1.7 * sigma);
  const bias = (0.5 - 0.5 * gain) * 255;
  const img = bctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    d[i] = d[i + 1] = d[i + 2] = 255;
    d[i + 3] = Math.min(255, Math.max(0, gain * d[i + 3] + bias));
  }
  bctx.putImageData(img, 0, 0);
  return blurred;
}
