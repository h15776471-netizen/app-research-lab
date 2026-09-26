// SVG path "d" → mupdf.Path (M L H V C S Q T A Z, absolute + relative).
import * as mupdf from 'mupdf';

function arcToBeziers(x1, y1, rx, ry, phi, fa, fs, x2, y2) {
  // Implementation of SVG arc → cubic beziers (W3C F.6.5).
  const out = [];
  if (rx === 0 || ry === 0) return [[x1, y1, x2, y2, x2, y2]];
  const sinp = Math.sin(phi), cosp = Math.cos(phi);
  const dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
  const x1p = cosp * dx + sinp * dy, y1p = -sinp * dx + cosp * dy;
  rx = Math.abs(rx); ry = Math.abs(ry);
  const lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lam > 1) { rx *= Math.sqrt(lam); ry *= Math.sqrt(lam); }
  const num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  const den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  let co = Math.sqrt(Math.max(0, num / den));
  if (fa === fs) co = -co;
  const cxp = (co * rx * y1p) / ry, cyp = (-co * ry * x1p) / rx;
  const cx = cosp * cxp - sinp * cyp + (x1 + x2) / 2;
  const cy = sinp * cxp + cosp * cyp + (y1 + y2) / 2;
  const ang = (ux, uy, vx, vy) => {
    const a = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
    return a;
  };
  let t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  let dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
  if (!fs && dt > 0) dt -= 2 * Math.PI;
  if (fs && dt < 0) dt += 2 * Math.PI;
  const segs = Math.ceil(Math.abs(dt) / (Math.PI / 2));
  const d = dt / segs;
  const k = (4 / 3) * Math.tan(d / 4);
  let t = t1;
  const pt = (a) => [cx + rx * Math.cos(a) * cosp - ry * Math.sin(a) * sinp, cy + rx * Math.cos(a) * sinp + ry * Math.sin(a) * cosp];
  const dpt = (a) => [-rx * Math.sin(a) * cosp - ry * Math.cos(a) * sinp, -rx * Math.sin(a) * sinp + ry * Math.cos(a) * cosp];
  for (let i = 0; i < segs; i++) {
    const [ax, ay] = pt(t), [bx, by] = pt(t + d);
    const [dax, day] = dpt(t), [dbx, dby] = dpt(t + d);
    out.push([ax + k * dax, ay + k * day, bx - k * dbx, by - k * dby, bx, by]);
    t += d;
  }
  return out;
}

export function svgPathToMupdf(d, tx = (x, y) => [x, y]) {
  const p = new mupdf.Path();
  const toks = d.match(/[a-zA-Z]|-?(?:\d*\.\d+|\d+\.?)(?:e[-+]?\d+)?/g);
  let i = 0, cmd = '', x = 0, y = 0, sx = 0, sy = 0, lcx = 0, lcy = 0, lqx = 0, lqy = 0, prev = '';
  const num = () => parseFloat(toks[i++]);
  const flag = () => { // arc flags may be glued: "a10 10 0 01..."
    const t = toks[i];
    if (t.length > 1 && (t[0] === '0' || t[0] === '1') && !t.includes('.')) { toks[i] = t.slice(1); return t[0] === '1'; }
    i++; return t === '1' || parseFloat(t) === 1;
  };
  const M = (a, b) => p.moveTo(...tx(a, b));
  const L = (a, b) => p.lineTo(...tx(a, b));
  const C = (a, b, c, e, f, g) => p.curveTo(...tx(a, b), ...tx(c, e), ...tx(f, g));
  while (i < toks.length) {
    if (/[a-zA-Z]/.test(toks[i])) cmd = toks[i++];
    const rel = cmd === cmd.toLowerCase();
    const ox = rel ? x : 0, oy = rel ? y : 0;
    switch (cmd.toUpperCase()) {
      case 'M': { x = ox + num(); y = oy + num(); sx = x; sy = y; M(x, y); cmd = rel ? 'l' : 'L'; break; }
      case 'L': { x = ox + num(); y = oy + num(); L(x, y); break; }
      case 'H': { x = (rel ? x : 0) + num(); L(x, y); break; }
      case 'V': { y = (rel ? y : 0) + num(); L(x, y); break; }
      case 'C': { const a = ox + num(), b = oy + num(), c = ox + num(), e = oy + num(); x = ox + num(); y = oy + num(); C(a, b, c, e, x, y); lcx = c; lcy = e; break; }
      case 'S': {
        const a = /[CS]/i.test(prev) ? 2 * x - lcx : x, b = /[CS]/i.test(prev) ? 2 * y - lcy : y;
        const c = ox + num(), e = oy + num(); x = ox + num(); y = oy + num(); C(a, b, c, e, x, y); lcx = c; lcy = e; break;
      }
      case 'Q': {
        const qx = ox + num(), qy = oy + num(), nx = ox + num(), ny = oy + num();
        C(x + (2 / 3) * (qx - x), y + (2 / 3) * (qy - y), nx + (2 / 3) * (qx - nx), ny + (2 / 3) * (qy - ny), nx, ny);
        x = nx; y = ny; lqx = qx; lqy = qy; break;
      }
      case 'T': {
        const qx = /[QT]/i.test(prev) ? 2 * x - lqx : x, qy = /[QT]/i.test(prev) ? 2 * y - lqy : y;
        const nx = ox + num(), ny = oy + num();
        C(x + (2 / 3) * (qx - x), y + (2 / 3) * (qy - y), nx + (2 / 3) * (qx - nx), ny + (2 / 3) * (qy - ny), nx, ny);
        x = nx; y = ny; lqx = qx; lqy = qy; break;
      }
      case 'A': {
        const rx = num(), ry = num(), rot = num(), fa = flag(), fs = flag();
        const nx = ox + num(), ny = oy + num();
        for (const s of arcToBeziers(x, y, rx, ry, (rot * Math.PI) / 180, fa, fs, nx, ny)) C(...s);
        x = nx; y = ny; break;
      }
      case 'Z': { p.closePath(); x = sx; y = sy; break; }
      default: i++;
    }
    prev = cmd;
  }
  return p;
}
