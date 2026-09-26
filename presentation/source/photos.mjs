// Story photo crops (16:9 + square thumbs) and a bottom gradient overlay (RGBA PNG).
import * as mupdf from 'mupdf';
import fs from 'fs';
import zlib from 'zlib';

const P = 'C:/Users/AL-NOOR/Downloads/app-research-lab/app-research-lab/presentation/assets/photos';

function crop(src, out, fx0, fy0, fw, fh, outW, outH, q = 86) {
  const img = new mupdf.Image(fs.readFileSync(`${P}/${src}`));
  const W = img.getWidth(), H = img.getHeight();
  const x0 = fx0 * W, y0 = fy0 * H, cw = fw * W, ch = fh * H;
  const sx = outW / cw, sy = outH / ch;
  const pix = new mupdf.Pixmap(mupdf.ColorSpace.DeviceRGB, [0, 0, outW, outH], false);
  pix.clear(255);
  const dev = new mupdf.DrawDevice(mupdf.Matrix.identity, pix);
  dev.fillImage(img, [W * sx, 0, 0, H * sy, -x0 * sx, -y0 * sy], 1);
  dev.close();
  fs.writeFileSync(`${P}/${out}`, pix.asJPEG(q, false));
}
// 16:9 crops (source images are 3:2 → keep full width, choose vertical window)
const r169 = (w, h) => (w / h) / (16 / 9); // fraction of height to keep when full width
for (const [name, fy0] of [['bride', 0.0], ['students', 0.06], ['team', 0.08]]) {
  const img = new mupdf.Image(fs.readFileSync(`${P}/${name}.jpg`));
  const fh = r169(img.getWidth(), img.getHeight());
  crop(`${name}.jpg`, `story_${name}.jpg`, 0, Math.min(fy0, 1 - fh), 1, fh, 1920, 1080);
}
// square thumbnails centred on the subjects (fractions of source w/h)
const thumbs = { bride: [0.3, 0.0, 0.62], students: [0.2, 0.02, 0.62], team: [0.18, 0.06, 0.62] };
for (const [name, [x0, y0, fw]] of Object.entries(thumbs)) {
  const img = new mupdf.Image(fs.readFileSync(`${P}/${name}.jpg`));
  const fh = (fw * img.getWidth()) / img.getHeight();
  crop(`${name}.jpg`, `thumb_${name}.jpg`, x0, y0, fw, fh, 640, 640);
}

// bottom gradient overlay: transparent → deep night (1A0F11)
function rgbaPng(w, h, px) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const o = y * (w * 4 + 1) + 1 + x * 4;
      const [r, g, b, a] = px(x, y);
      raw[o] = r; raw[o + 1] = g; raw[o + 2] = b; raw[o + 3] = a;
    }
  }
  const crcT = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
  const crc = (b) => { let c = -1; for (const v of b) c = crcT[(c ^ v) & 0xff] ^ (c >>> 8); return (c ^ -1) >>> 0; };
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
fs.writeFileSync(`${P}/overlay_bottom.png`, rgbaPng(800, 450, (x, y) => {
  const t = y / 449;                                   // 0 top → 1 bottom
  const k = t < 0.35 ? 0.18 * (t / 0.35) : 0.18 + 0.78 * Math.pow((t - 0.35) / 0.65, 1.15);
  return [26, 15, 17, Math.round(Math.min(0.95, k) * 255)];
}));
console.log('photos ready:', fs.readdirSync(P).join(', '));
