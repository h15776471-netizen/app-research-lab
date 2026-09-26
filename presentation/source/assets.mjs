// Builds presentation assets: phone mockups, icons, gradient backgrounds.
import * as mupdf from 'mupdf';
import fs from 'fs';
import path from 'path';
import zlib from 'zlib';
import { createRequire } from 'module';
import { svgPathToMupdf } from './svgpath.mjs';
const require = createRequire(import.meta.url);
const fas = require('@fortawesome/free-solid-svg-icons');
const fab = require('@fortawesome/free-brands-svg-icons');

const OUT = process.argv[2];
const SHOTS = path.resolve('shots');
fs.mkdirSync(path.join(OUT, 'phones'), { recursive: true });
fs.mkdirSync(path.join(OUT, 'icons'), { recursive: true });
fs.mkdirSync(path.join(OUT, 'bg'), { recursive: true });

// ── minimal PNG encoder (RGB/RGBA) ─────────────────────────────────────────
const crcTable = new Int32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c;
});
const crc = (buf) => { let c = -1; for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ -1) >>> 0; };
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, c]);
}
function png(w, h, pixel /* (x,y)=>[r,g,b] */) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 3 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const [r, g, b] = pixel(x, y);
      const o = y * (w * 3 + 1) + 1 + x * 3;
      raw[o] = r; raw[o + 1] = g; raw[o + 2] = b;
    }
  }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
function pngFromPixmap(pix) {
  const w = pix.getWidth(), h = pix.getHeight(), n = pix.getNumberOfComponents();
  const stride = pix.getStride(), src = pix.getPixels();
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const i = y * stride + x * n, o = y * (w * 4 + 1) + 1 + x * 4;
      const a = n === 4 ? src[i + 3] : 255;
      const un = (v) => (a === 0 ? 0 : Math.min(255, Math.round((v * 255) / a)));
      raw[o] = un(src[i]); raw[o + 1] = un(src[i + 1]); raw[o + 2] = un(src[i + 2]); raw[o + 3] = a;
    }
  }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
const hex = (h) => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
const mix = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t));

// ── gradient backgrounds (16:9, 1600x900) ──────────────────────────────────
function gradient(name, stops, { radial = null } = {}) {
  const W = 1600, H = 900;
  const cols = stops.map(([c, p]) => [hex(c), p]);
  const at = (t) => {
    for (let i = 0; i < cols.length - 1; i++) {
      const [c1, p1] = cols[i], [c2, p2] = cols[i + 1];
      if (t <= p2) return mix(c1, c2, (t - p1) / (p2 - p1 || 1));
    }
    return cols[cols.length - 1][0];
  };
  fs.writeFileSync(path.join(OUT, 'bg', name + '.png'), png(W, H, (x, y) => {
    let t = (x / W) * 0.55 + (1 - y / H) * 0.45; // diagonal
    t = Math.min(1, Math.max(0, t));
    let c = at(t);
    if (radial) { // soft glow
      const [gx, gy, gr, gc, ga] = radial;
      const d = Math.hypot(x - gx * W, y - gy * H) / (gr * W);
      const k = Math.max(0, 1 - d) ** 2 * ga;
      c = mix(c, hex(gc), k);
    }
    return c;
  }));
}
gradient('dark', [['1A0F11', 0], ['3A1220', 0.55], ['6E1E33', 1]], { radial: [0.78, 0.25, 0.55, 'A0465E', 0.35] });
gradient('dark_soft', [['1A0F11', 0], ['2A1418', 0.6], ['4B1222', 1]], { radial: [0.2, 0.2, 0.6, '6E1E33', 0.35] });
gradient('ivory', [['FFFFFF', 0], ['FAF7F2', 0.6], ['F4ECDD', 1]]);

// ── icons ───────────────────────────────────────────────────────────────────
const icons = {
  bride: fas.faPersonDress, ring: fas.faRing, grad: fas.faGraduationCap, users: fas.faUsers,
  briefcase: fas.faBriefcase, building: fas.faBuilding, hall: fas.faLandmark, camera: fas.faCamera,
  flower: fas.faSeedling, rose: fas.faSpa, car: fas.faCarSide, sparkle: fas.faWandMagicSparkles, clock: fas.faClock,
  phone: fas.faPhone, question: fas.faQuestion, chat: fas.faCommentDots, instagram: fab.faInstagram,
  facebook: fab.faFacebook, whatsapp: fab.faWhatsapp, search: fas.faMagnifyingGlass, list: fas.faListUl,
  money: fas.faMoneyBillWave, x: fas.faXmark, check: fas.faCheck, headset: fas.faHeadset, store: fas.faStore,
  image: fas.faImages, tag: fas.faTag, send: fas.faPaperPlane, shield: fas.faShieldHalved, pin: fas.faLocationDot,
  percent: fas.faPercent, star: fas.faStar, calendar: fas.faCalendarCheck, layers: fas.faLayerGroup,
  handshake: fas.faHandshake, file: fas.faFilePdf, eye: fas.faEye, rocket: fas.faRocket, city: fas.faCity,
  chart: fas.faChartLine, box: fas.faBoxOpen, user: fas.faUser, hash: fas.faHashtag, arrow: fas.faArrowLeft,
  mobile: fas.faMobileScreen, login: fas.faRightToBracket, grid: fas.faTableCellsLarge, gift: fas.faGift,
  listcheck: fas.faListCheck, heart: fas.faHeart, bolt: fas.faBolt, route: fas.faRoute,
  pen: fas.faPenToSquare, upload: fas.faUpload, badge: fas.faCircleCheck, hourglass: fas.faHourglassHalf,
  people: fas.faPeopleGroup, cake: fas.faCakeCandles, music: fas.faMusic, envelope: fas.faEnvelopeOpenText,
  crown: fas.faCrown, bell: fas.faBell, arrowdown: fas.faArrowDown,
};
const colors = { maroon: '6E1E33', gold: 'B08D57', white: 'FFFFFF', champagne: 'E8D8BD', charcoal: '221C1B', grey: '8A807C', red: 'B3261E', green: '2F6B4F' };
for (const [name, def] of Object.entries(icons)) {
  if (!def) { console.error('missing icon', name); continue; }
  const [w, h, , , d] = def.icon;
  const paths = Array.isArray(d) ? d : [d];
  const S = 256, pad = 8, sc = (S - 2 * pad) / Math.max(w, h);
  const ox = (S - w * sc) / 2, oy = (S - h * sc) / 2;
  for (const [cname, c] of Object.entries(colors)) {
    const pix = new mupdf.Pixmap(mupdf.ColorSpace.DeviceRGB, [0, 0, S, S], true);
    pix.clear();
    const dev = new mupdf.DrawDevice(mupdf.Matrix.identity, pix);
    for (const pd of paths) {
      const p = svgPathToMupdf(pd, (x, y) => [ox + x * sc, oy + y * sc]);
      dev.fillPath(p, false, mupdf.Matrix.identity, mupdf.ColorSpace.DeviceRGB, hex(c).map((v) => v / 255), 1);
    }
    dev.close();
    fs.writeFileSync(path.join(OUT, 'icons', `${name}_${cname}.png`), pngFromPixmap(pix));
  }
}

// ── phone mockups ───────────────────────────────────────────────────────────
function roundRect(x, y, w, h, r) {
  const p = new mupdf.Path();
  const k = 0.5523 * r;
  p.moveTo(x + r, y); p.lineTo(x + w - r, y);
  p.curveTo(x + w - r + k, y, x + w, y + r - k, x + w, y + r);
  p.lineTo(x + w, y + h - r);
  p.curveTo(x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h);
  p.lineTo(x + r, y + h);
  p.curveTo(x + r - k, y + h, x, y + h - r + k, x, y + h - r);
  p.lineTo(x, y + r);
  p.curveTo(x, y + r - k, x + r - k, y, x + r, y);
  p.closePath();
  return p;
}
const rgb = (h) => hex(h).map((v) => v / 255);
function phone(name) {
  const src = path.join(SHOTS, name + '.png');
  const img = new mupdf.Image(fs.readFileSync(src));
  const sw = img.getWidth(), sh = img.getHeight();
  const top = 140;                          // status bar strip
  const bez = 44, W = sw + bez * 2, H = sh + top + bez * 2;
  const pix = new mupdf.Pixmap(mupdf.ColorSpace.DeviceRGB, [0, 0, W, H], true);
  pix.clear();
  const dev = new mupdf.DrawDevice(mupdf.Matrix.identity, pix);
  const I = mupdf.Matrix.identity, cs = mupdf.ColorSpace.DeviceRGB;
  dev.fillPath(roundRect(0, 0, W, H, 190), false, I, cs, rgb('17110F'), 1);        // body
  dev.fillPath(roundRect(6, 6, W - 12, H - 12, 184), false, I, cs, rgb('2B2422'), 1); // rim highlight
  dev.fillPath(roundRect(14, 14, W - 28, H - 28, 176), false, I, cs, rgb('0C0908'), 1);
  // screen clip
  dev.clipPath(roundRect(bez, bez, sw, sh + top, 150), false, I);
  // status strip uses the screenshot's top-left color
  const probe = img.toPixmap();
  const n = probe.getNumberOfComponents();
  const px = probe.getPixels();
  const c0 = [px[(10 * probe.getStride()) / 1 + 10 * n] ?? 250, px[10 * probe.getStride() + 10 * n + 1] ?? 247, px[10 * probe.getStride() + 10 * n + 2] ?? 242];
  const strip = [px[0], px[1], px[2]].map((v) => v / 255);
  dev.fillPath(roundRect(bez, bez, sw, top + 40, 0), false, I, cs, strip, 1);
  dev.fillImage(img, [sw, 0, 0, sh, bez, bez + top], 1);
  dev.popClip();
  // dynamic island
  const dark = (strip[0] + strip[1] + strip[2]) / 3 < 0.5;
  dev.fillPath(roundRect(W / 2 - 170, bez + 34, 340, 92, 46), false, I, cs, [0, 0, 0], 1);
  // status icons (time + battery) as simple shapes
  const ink = dark ? [1, 1, 1] : [0.13, 0.11, 0.1];
  dev.fillPath(roundRect(W - bez - 190, bez + 62, 96, 40, 12), false, I, cs, ink, 0.9);   // battery
  dev.fillPath(roundRect(W - bez - 90, bez + 74, 8, 16, 3), false, I, cs, ink, 0.9);
  for (let i = 0; i < 4; i++) dev.fillPath(roundRect(W - bez - 300 + i * 22, bez + 102 - (i + 1) * 10, 14, (i + 1) * 10, 3), false, I, cs, ink, 0.9); // signal
  dev.fillPath(roundRect(bez + 110, bez + 66, 120, 34, 17), false, I, cs, ink, 0.85);   // time pill
  // side buttons
  dev.close();
  // downscale to ~55%
  const scale = 0.55;
  const out = new mupdf.Pixmap(mupdf.ColorSpace.DeviceRGB, [0, 0, Math.round(W * scale), Math.round(H * scale)], true);
  out.clear();
  const d2 = new mupdf.DrawDevice(mupdf.Matrix.identity, out);
  const im2 = new mupdf.Image(pix);
  d2.fillImage(im2, [W * scale, 0, 0, H * scale, 0, 0], 1);
  d2.close();
  fs.writeFileSync(path.join(OUT, 'phones', name + '.png'), pngFromPixmap(out));
  return [out.getWidth(), out.getHeight()];
}
const sizes = {};
for (const f of fs.readdirSync(SHOTS).filter((f) => f.endsWith('.png'))) {
  const n = f.replace('.png', '');
  sizes[n] = phone(n);
}
fs.writeFileSync(path.join(OUT, 'phones', 'sizes.json'), JSON.stringify(sizes, null, 1));
console.log('phones:', Object.keys(sizes).join(', '));
console.log('icons:', Object.keys(icons).length);
