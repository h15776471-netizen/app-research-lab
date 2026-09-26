// SAWA pitch deck (Arabic, RTL) — pptxgenjs.
const path = require('path');
const fs = require('fs');
const pptxgen = require('pptxgenjs');

const ROOT = 'C:/Users/AL-NOOR/Downloads/app-research-lab/app-research-lab/presentation';
const A = (p) => path.join(ROOT, 'assets', p);
const OUT = path.join(ROOT, 'SAWA_Presentation_AR.pptx');
const sizes = JSON.parse(fs.readFileSync(A('phones/sizes.json'), 'utf8'));

const C = {
  maroon: '6E1E33', deep: '4B1222', night: '1A0F11', ivory: 'FAF7F2', white: 'FFFFFF',
  champagne: 'E8D8BD', champSoft: 'F4ECDD', gold: 'B08D57', charcoal: '221C1B', grey: '6E6461',
  line: 'E8E1D8', soft: 'F5ECEE',
};
const F = 'Segoe UI';
const W = 13.333, H = 7.5, M = 0.6;

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE';
pres.title = 'SAWA عرض المشروع';
pres.author = 'بنين وليد · حوراء حسن · فنار حسن';
pres.company = 'SAWA';
pres.rtlMode = true;

// ── helpers ────────────────────────────────────────────────────────────────
function T(s, text, o) {
  s.addText(text, {
    fontFace: F, color: C.charcoal, fontSize: 18, align: 'right', valign: 'top', margin: 0,
    rtlMode: true, lang: 'ar-IQ', isTextBox: true, fit: 'none', ...o, ...(o && o.rtlMode === false ? { lang: 'en-US' } : {}),
  });
}
function icon(s, name, color, x, y, d) {
  s.addImage({ path: A(`icons/${name}_${color}.png`), x, y, w: d, h: d });
}
function iconCircle(s, name, iconColor, fill, x, y, d, ratio = 0.46) {
  s.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: fill }, line: { color: fill } });
  const i = d * ratio;
  icon(s, name, iconColor, x + (d - i) / 2, y + (d - i) / 2, i);
}
function card(s, x, y, w, h, fill = C.white, o = {}) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: o.r ?? 0.18, fill: { color: fill, transparency: o.transparency ?? 0 },
    line: { color: o.line ?? (fill === C.white ? C.line : fill), width: o.lineW ?? 0.75, transparency: o.lineT ?? 0 },
    shadow: o.shadow === false ? undefined : { type: 'outer', color: '3B2A25', opacity: 0.12, blur: 12, offset: 3, angle: 90 },
  });
}
function phone(s, name, x, y, h) {
  const [pw, ph] = sizes[name];
  const w = (h * pw) / ph;
  s.addImage({
    path: A(`phones/${name}.png`), x, y, w, h,
    shadow: { type: 'outer', color: '000000', opacity: 0.35, blur: 22, offset: 8, angle: 90 },
  });
  return w;
}
function bg(s, name) { s.background = { path: A(`bg/${name}.png`) }; }
function kicker(s, text, x, y, w, color = C.gold) {
  T(s, text, { x, y, w, h: 0.4, fontSize: 14, bold: true, color });
}
function pageNo(s, n, dark = false) {
  AN = null;
  T(s, String(n).padStart(2, '0'), { x: 0.35, y: H - 0.5, w: 0.6, h: 0.3, fontSize: 10, color: dark ? C.champagne : C.grey, align: 'left', rtlMode: false });
  T(s, 'SAWA', { x: W - 1.35, y: H - 0.5, w: 1.0, h: 0.3, fontSize: 10, bold: true, charSpacing: 3, color: dark ? C.champagne : C.maroon, rtlMode: false });
}
function chip(s, text, iconName, x, y, w, h = 0.62, o = {}) {
  const fill = o.fill ?? C.white, color = o.color ?? C.charcoal, ic = o.iconColor ?? 'maroon';
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: h / 2, fill: { color: fill }, line: { color: o.line ?? fill },
    shadow: { type: 'outer', color: '000000', opacity: 0.18, blur: 10, offset: 3, angle: 90 },
  });
  const d = h * 0.52;
  icon(s, iconName, ic, x + w - d - h * 0.34, y + (h - d) / 2, d);
  T(s, text, { x: x + 0.2, y, w: w - d - h * 0.34 - 0.32, h, fontSize: o.size ?? 16, bold: true, color, valign: 'middle' });
}
const notes = (s, t) => s.addNotes(t);

// Animation tagging — applied later in PowerPoint by source/apply_anim.ps1.
let AN = null, UID = 0;
const anim = (step, fx = 'fade') => { AN = step == null ? null : { step, fx }; };
const _addSlide = pres.addSlide.bind(pres);
pres.addSlide = (...a) => {
  const sl = _addSlide(...a);
  AN = null;
  const tag = (o) => (AN && !(o && o.objectName) ? { ...o, objectName: `anim|${AN.step}|${AN.fx}|${++UID}` } : o);
  const aS = sl.addShape.bind(sl), aI = sl.addImage.bind(sl), aT = sl.addText.bind(sl);
  sl.addShape = (t, o) => aS(t, tag(o));
  sl.addImage = (o) => aI(tag(o));
  sl.addText = (t, o) => aT(t, tag(o));
  return sl;
};

// ═══ 1. Cover ══════════════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'dark');
  anim(1, 'flyup');
  phone(s, 'details', 0.9, 1.15, 5.9);
  phone(s, 'home', 2.95, 0.55, 6.5);
  anim(2, 'zoom');
  T(s, 'SAWA', { x: 6.6, y: 1.35, w: 6.1, h: 1.5, fontSize: 96, bold: true, color: C.white, charSpacing: 6, rtlMode: false });
  anim(3, 'fade');
  T(s, 'سوا، منصة للمناسبات', { x: 6.6, y: 2.85, w: 6.1, h: 0.6, fontSize: 24, color: C.champagne });
  anim(4, 'rise');
  T(s, 'كل ما تحتاجه مناسبتك... بمكان واحد.', { x: 6.6, y: 3.6, w: 6.1, h: 0.7, fontSize: 28, bold: true, color: C.white });
  T(s, 'قاعات وتصوير وورد وكل خدمات المناسبات، ونبدأ من بغداد', { x: 6.6, y: 4.35, w: 6.1, h: 0.5, fontSize: 16, color: C.champagne });
  anim(5, 'fade');
  kicker(s, 'فريق العمل', 6.6, 5.35, 6.1, C.gold);
  const names = ['بنين وليد', 'حوراء حسن', 'فنار حسن'];
  names.forEach((n, i) => {
    anim(6 + i, 'zoom');
    const w = 1.85, x = W - M - 0.05 - (i + 1) * w - i * 0.15;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 5.8, w, h: 0.58, rectRadius: 0.29, fill: { color: C.white, transparency: 88 }, line: { color: C.champagne, width: 1 } });
    T(s, n, { x, y: 5.8, w, h: 0.58, fontSize: 16, bold: true, color: C.white, align: 'center', valign: 'middle' });
  });
  notes(s, 'افتتاح: نعرّف بأنفسنا بسرعة. لا نبدأ بتعريف التطبيق، نبدأ بقصة. الهواتف تعرض شاشات حقيقية من تطبيق SAWA.');
}

// ═══ 2–4. Stories ══════════════════════════════════════════════════════════
function story(n, { photo, chips, kick, title, body, script }) {
  const s = pres.addSlide();
  s.background = { color: '1A0F11' };
  anim(1, 'fade');
  s.addImage({ path: A(`photos/story_${photo}.jpg`), x: 0, y: 0, w: W, h: H });
  s.addImage({ path: A('photos/overlay_bottom.png'), x: 0, y: 0, w: W, h: H });
  chips.forEach(([t, ic, gold, x, y], i) => {
    anim(3 + i, 'zoom');
    chip(s, t, ic, x, y, 2.3, 0.6, gold ? { fill: C.gold, color: C.white, iconColor: 'white', size: 15 } : { size: 15 });
  });
  anim(2, 'rise');
  T(s, kick, { x: 4.2, y: 4.45, w: 8.5, h: 0.4, fontSize: 15, bold: true, color: C.champagne });
  T(s, title, { x: 3.2, y: 4.85, w: 9.5, h: 1.0, fontSize: 40, bold: true, color: C.white });
  anim(9, 'fade');
  T(s, body, { x: 4.2, y: 5.9, w: 8.5, h: 0.9, fontSize: 18, color: C.champagne });
  pageNo(s, n + 1, true);
  notes(s, script);
  return s;
}

story(1, {
  photo: 'bride', kick: 'القصة الأولى',
  title: 'عروس، وعرسها قرّب',
  body: 'قاعة وورد وسيارة ومصوّر، وعشرات الصفحات والاتصالات، وما تعرف منين تبدي.',
  chips: [['أي قاعة؟', 'hall', false, 0.6, 0.7], ['ورد؟', 'rose', false, 2.4, 1.6], ['كم السعر؟', 'money', false, 0.5, 2.5], ['الوقت يضغط', 'clock', true, 2.3, 3.4]],
  script: 'نبدأ بقصة. تخيلوا عروس باقي على عرسها أسابيع قليلة. كل يوم تفتح Instagram: عشرات صفحات القاعات، والورد، والسيارات، والمصورين. كل صفحة تطلب منها تراسلهم على الخاص حتى تعرف السعر، ونص الصفحات ما يردون. تكتب أسماء بدفتر، تتصل، تنتظر... والوقت يمشي. هي مو ناقصها ذوق، ناقصها مكان واحد تشوف بيه كلشي بوضوح.',
});
story(2, {
  photo: 'students', kick: 'القصة الثانية',
  title: 'التخرج قرّب، ولسه ما عدنا قاعة',
  body: 'كل واحد يدوّر بتلفونه، وماكو وقت نتصل بكل القاعات ونقارن بيناتها.',
  chips: [['قاعة تكفينا؟', 'hall', false, 0.5, 0.35], ['الأسعار؟', 'money', false, 2.95, 0.35], ['اتصالات كثيرة', 'phone', false, 5.4, 0.35], ['التاريخ قريب', 'calendar', true, 7.85, 0.35]],
  script: 'القصة الثانية: طلاب مرحلة رابعة، حفل التخرج بعد شهر. كل واحد بالمجموعة ماسك تلفونه ويدوّر بمكان: واحد بإنستغرام، واحد يسأل أقاربه، وواحد يتصل بقاعة ما ترد. عندهم امتحانات ومشاريع، وما عندهم وقت يزورون عشر قاعات ويقارنون الأسعار والسعة والخدمات. يحتاجون يعرفون بسرعة: شنو القاعات اللي تكفينا وبميزانيتنا؟',
});
story(3, {
  photo: 'team', kick: 'القصة الثالثة',
  title: 'الشركة عدها Event، والفريق ضايع',
  body: 'قاعة ومصوّر وورد وسيارات، وكل واحد بالفريق يدوّر بمكان.',
  chips: [['القاعة؟', 'hall', false, 2.2, 0.4], ['المصوّر؟', 'camera', false, 4.65, 0.4], ['الورد؟', 'rose', false, 7.1, 0.4], ['موعد قريب', 'clock', true, 9.3, 1.3]],
  script: 'القصة الثالثة: شركة عندها حفل أو مؤتمر بعد أسبوعين. المدير يطلب من الفريق يرتبون كلشي: قاعة، مصور، ورد، سيارات. كل موظف يدوّر بطريقته، وعدهم خمس محادثات واتساب وجداول وأرقام متفرقة، وبالنهاية ماكو قرار واحد واضح.',
});

// ═══ 5. The shared problem ═════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'dark_soft');
  const icons3 = ['briefcase', 'grad', 'bride'];
  anim(1, 'zoom');
  ['team', 'students', 'bride'].forEach((ph, i) => {
    const d = 1.35, x = 3.95 + i * 1.95, y = 0.6;
    s.addShape(pres.shapes.OVAL, { x: x - 0.05, y: y - 0.05, w: d + 0.1, h: d + 0.1, fill: { color: C.champagne }, line: { color: C.champagne } });
    s.addImage({ path: A(`photos/thumb_${ph}.jpg`), x, y, w: d, h: d, rounding: true });
  });
  anim(2, 'fade');
  T(s, 'ثلاث قصص مختلفة...', { x: M, y: 2.2, w: W - 2 * M, h: 0.8, fontSize: 30, color: C.champagne, align: 'center' });
  anim(3, 'zoom');
  T(s, 'لكن المشكلة واحدة.', { x: M, y: 2.9, w: W - 2 * M, h: 1.1, fontSize: 52, bold: true, color: C.white, align: 'center' });
  const items = [['وقت ضائع', 'clock'], ['معلومات متفرقة', 'layers'], ['خيارات كثيرة', 'grid'], ['اتصالات لا تنتهي', 'phone']];
  const tw = 2.55, gap = 0.55, total = items.length * tw + (items.length - 1) * gap, x0 = (W - total) / 2;
  items.forEach(([t, ic], i) => {
    anim(4 + i, 'rise');
    const x = W - x0 - (i + 1) * tw - i * gap;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 4.6, w: tw, h: 1.95, rectRadius: 0.22, fill: { color: C.white, transparency: 90 }, line: { color: C.champagne, width: 0.75, transparency: 50 } });
    iconCircle(s, ic, 'white', C.maroon, x + tw / 2 - 0.42, 4.85, 0.84, 0.48);
    T(s, t, { x, y: 5.85, w: tw, h: 0.5, fontSize: 18, bold: true, color: C.white, align: 'center' });
    if (i < items.length - 1) T(s, '+', { x: x - gap, y: 5.2, w: gap, h: 0.7, fontSize: 30, bold: true, color: C.gold, align: 'center', rtlMode: false });
  });
  pageNo(s, 5, true);
  notes(s, 'نجمع القصص الثلاث: المشكلة ليست بالشخص، بل بطريقة الوصول للمعلومة. أربع كلمات تلخص المعاناة.');
}

// ═══ 6. Enter SAWA ═════════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'dark');
  anim(1, 'fade');
  T(s, 'وهنا...', { x: 6.2, y: 1.6, w: 6.5, h: 0.8, fontSize: 32, color: C.champagne });
  anim(2, 'zoom');
  T(s, 'يأتي SAWA', { x: 6.2, y: 2.35, w: 6.5, h: 1.4, fontSize: 72, bold: true, color: C.white });
  anim(4, 'fade');
  T(s, 'مكان واحد تلكى بيه القاعات والورد والمصورين بصورهم وأسعارهم، ووياه فريق يتابع طلبك.', { x: 6.2, y: 3.95, w: 6.3, h: 1.1, fontSize: 20, color: C.champagne });
  const tags = [['اكتشف', 'search'], ['قارن', 'listcheck'], ['تواصل', 'send']];
  tags.forEach(([t, ic], i) => (anim(5 + i, 'zoom'), chip(s, t, ic, 12.7 - (i + 1) * 1.95 - i * 0.15, 5.4, 1.95, 0.62, { fill: C.white, color: C.maroon })));
  anim(3, 'flyup');
  phone(s, 'home', 1.6, 0.45, 6.6);
  pageNo(s, 6, true);
  notes(s, 'لحظة الانتقال: نفتح الهاتف ونظهر SAWA. ثلاث كلمات: اكتشف، قارن، تواصل.');
}

// ═══ 7. How it works (journey) ═════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'fade');
  kicker(s, 'رحلة المستخدم', M, 0.7, W - 2 * M);
  T(s, 'كيف يعمل SAWA؟', { x: M, y: 1.05, w: W - 2 * M, h: 0.9, fontSize: 40, bold: true });
  const steps = [
    ['افتح التطبيق', 'mobile', 'من الهاتف أو المتصفح'], ['سجّل أو تصفّح كزائر', 'login', 'الحساب اختياري'],
    ['الرئيسية والفئات', 'grid', 'قاعات، تصوير، ورد'], ['صور وأسعار وخدمات', 'image', 'معلومات منظمة'],
    ['قارن واختر', 'listcheck', 'بحث وفلاتر'], ['اطلب تواصل', 'send', 'برقم مرجعي'],
  ];
  const n = steps.length, sw = 1.85, gap = (W - 2 * M - n * sw) / (n - 1);
  anim(2, 'wipe');
  s.addShape(pres.shapes.LINE, { x: M + sw / 2, y: 3.35, w: W - 2 * M - sw, h: 0, line: { color: C.champagne, width: 2, dashType: 'dash' } });
  steps.forEach(([t, ic, sub], i) => {
    const x = W - M - (i + 1) * sw - i * gap;
    anim(3 + i, 'zoom');
    const last = i === n - 1;
    iconCircle(s, ic, 'white', last ? C.gold : C.maroon, x + sw / 2 - 0.55, 2.8, 1.1, 0.45);
    s.addShape(pres.shapes.OVAL, { x: x + sw / 2 + 0.28, y: 2.7, w: 0.42, h: 0.42, fill: { color: C.white }, line: { color: C.maroon, width: 1 } });
    T(s, String(i + 1), { x: x + sw / 2 + 0.28, y: 2.7, w: 0.42, h: 0.42, fontSize: 13, bold: true, color: C.maroon, align: 'center', valign: 'middle', rtlMode: false });
    T(s, t, { x: x - 0.1, y: 4.15, w: sw + 0.2, h: 0.9, fontSize: 17, bold: true, align: 'center' });
    T(s, sub, { x: x - 0.1, y: 5.0, w: sw + 0.2, h: 0.5, fontSize: 13, color: C.grey, align: 'center' });
  });
  anim(9, 'rise');
  card(s, 3.2, 5.85, W - 6.4, 0.8, C.soft, { shadow: false, line: C.soft });
  T(s, 'تكدر تتصفح وترسل طلب بدون حساب، وإذا سجّلت تتابع كل طلباتك من مكان واحد.', { x: 3.4, y: 5.85, w: W - 6.8, h: 0.8, fontSize: 16, color: C.maroon, align: 'center', valign: 'middle' });
  pageNo(s, 7);
  notes(s, 'الرحلة من اليمين لليسار. نؤكد أن الزائر غير مجبر على إنشاء حساب، هذا قرار مقصود لتقليل الاحتكاك.');
}

// ═══ 8. Home / categories ══════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'flyup');
  phone(s, 'home', 1.2, 0.45, 6.6);
  anim(2, 'fade');
  kicker(s, 'الصفحة الرئيسية', 5.6, 0.95, 7.1);
  T(s, 'من الحيرة إلى الاختيار', { x: 5.6, y: 1.3, w: 7.1, h: 0.9, fontSize: 40, bold: true });
  T(s, 'كل الفئات تبين من أول شاشة، ويا عدد المزودين الحقيقي بكل فئة.', { x: 5.6, y: 2.2, w: 7.1, h: 0.5, fontSize: 18, color: C.grey });
  const cats = [['القاعات', 'hall', '6 مزودين'], ['التصوير', 'camera', '5 مزودين'], ['الورد والزهور', 'rose', '4 مزودين'], ['السيارات', 'car', 'قريباً'], ['خدمات أخرى', 'sparkle', 'قريباً']];
  cats.forEach(([t, ic, cnt], i) => {
    anim(3 + i, 'rise');
    const y = 2.95 + i * 0.78, soon = cnt === 'قريباً';
    card(s, 6.6, y, 6.1, 0.64, soon ? C.ivory : C.white, soon ? { shadow: false, line: C.line } : {});
    iconCircle(s, ic, soon ? 'grey' : 'maroon', soon ? 'EFEAE3' : C.soft, 12.0, y + 0.07, 0.5, 0.52);
    T(s, t, { x: 8.6, y, w: 3.25, h: 0.64, fontSize: 18, bold: true, valign: 'middle', color: soon ? C.grey : C.charcoal });
    T(s, cnt, { x: 6.8, y, w: 1.8, h: 0.64, fontSize: 15, bold: !soon, valign: 'middle', align: 'left', color: soon ? C.gold : C.maroon });
  });
  pageNo(s, 8);
  notes(s, 'الأعداد حقيقية من قاعدة البيانات: 6 قاعات، 5 مصورين، 4 محلات ورد. السيارات وغيرها "قريباً"، عندنا كتالوجاتها لكن لم نضفها قبل التأكد من بياناتها.');
}

// ═══ 9. Browse halls & services ════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'fade');
  kicker(s, 'استعراض المزودين', M, 0.55, W - 2 * M);
  T(s, 'قاعات، تصوير، ورد', { x: M, y: 0.9, w: W - 2 * M, h: 0.9, fontSize: 40, bold: true });
  const list = [['cat_halls', 'القاعات', 'hall'], ['cat_photo', 'التصوير', 'camera'], ['cat_flowers', 'الورد والزهور', 'rose']];
  const ph = 4.85, pw = (ph * sizes.cat_halls[0]) / sizes.cat_halls[1], gap = 1.2, total = 3 * pw + 2 * gap, x0 = (W - total) / 2;
  list.forEach(([img, label, ic], i) => {
    anim(2 + i, 'flyup');
    const x = W - x0 - (i + 1) * pw - i * gap;
    phone(s, img, x, 1.9, ph);
    chip(s, label, ic, x + pw / 2 - 1.05, 6.55, 2.1, 0.55, { size: 15 });
  });
  pageNo(s, 9);
  notes(s, 'كل فئة فيها بحث وفلاتر (المنطقة، السعر، السعة، العروض)، ونعرض فقط الفلاتر التي تدعمها البيانات فعلاً.');
}

// ═══ 10. Provider page ═════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'flyup');
  phone(s, 'details', 0.7, 0.55, 6.4);
  anim(2, 'flyup');
  phone(s, 'details_pk', 3.75, 0.95, 6.0);
  anim(3, 'fade');
  kicker(s, 'صفحة المزوّد', 7.4, 0.95, 5.3);
  T(s, 'اختار... قارن... تواصل', { x: 7.4, y: 1.3, w: 5.3, h: 0.9, fontSize: 38, bold: true });
  const pts = [['صور حقيقية من المزوّد', 'image'], ['المنطقة والموقع', 'pin'], ['العروض والأسعار إذا متوفرة', 'tag'], ['الخدمات المتوفرة', 'listcheck'], ['زر اطلب تواصل', 'send']];
  pts.forEach(([t, ic], i) => {
    anim(4 + i, 'rise');
    const y = 2.55 + i * 0.8;
    iconCircle(s, ic, 'white', i === 4 ? C.gold : C.maroon, 12.1, y, 0.58, 0.46);
    T(s, t, { x: 7.4, y, w: 4.5, h: 0.58, fontSize: 19, bold: true, valign: 'middle' });
  });
  anim(9, 'fade');
  T(s, 'العروض المؤقتة تنكتب كعرض، مو كسعر ثابت.', { x: 7.4, y: 6.6, w: 5.3, h: 0.4, fontSize: 14, color: C.maroon, italic: true });
  pageNo(s, 10);
  notes(s, 'مثال حقيقي: قاعة الملكة. الصور مستخرجة من كتالوج المزود. العرض الصباحي والمسائي معروضان كعروض وليس كسعر أساسي.');
}

// ═══ 11. After the request ═════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(3, 'fade');
  kicker(s, 'ماذا يحدث بعد الطلب؟', 7.3, 0.95, 5.4);
  T(s, 'طلب واضح، ورقم مرجعي بنفس اللحظة', { x: 7.3, y: 1.3, w: 5.4, h: 1.5, fontSize: 36, bold: true });
  anim(4, 'fade');
  T(s, 'بس الاسم والرقم، وبدون حساب. الطلب يوصل لفريق SAWA أول، ورقم العميل ما يشوفه غيرنا.', { x: 7.3, y: 2.9, w: 5.4, h: 1.2, fontSize: 18, color: C.grey });
  anim(5, 'zoom');
  card(s, 7.3, 4.35, 5.4, 1.55, C.maroon, { line: C.maroon });
  icon(s, 'shield', 'champagne', 12.0, 4.6, 0.5);
  T(s, 'SAWA ما يوعد بحجز فوري', { x: 7.55, y: 4.5, w: 4.3, h: 0.5, fontSize: 20, bold: true, color: C.white });
  T(s, 'ماكو زر Book Now وهمي. نتأكد من التفاصيل ويا الطرفين قبل كلشي.', { x: 7.55, y: 5.0, w: 4.3, h: 0.8, fontSize: 15, color: C.champagne });
  anim(1, 'flyup');
  phone(s, 'contact', 0.8, 0.6, 6.1);
  anim(2, 'flyup');
  phone(s, 'success', 4.05, 0.6, 6.1);
  T(s, 'رقم مرجعي (مثال)', { x: 4.05, y: 6.78, w: 2.8, h: 0.3, fontSize: 12, color: C.grey, align: 'center' });
  pageNo(s, 11);
  notes(s, 'نؤكد الصدق: التطبيق لا يعد بحجز فوري. الرقم المرجعي في الشاشة مثال. كل طلب حقيقي يحصل على رقم فريد من الخادم.');
}

// ═══ 12. Request flow ══════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'fade');
  kicker(s, 'رحلة الطلب كاملة', M, 0.6, W - 2 * M);
  T(s, 'من الطلب إلى التأكيد', { x: M, y: 0.95, w: W - 2 * M, h: 0.9, fontSize: 40, bold: true });
  const nodes = [
    ['العميل', 'Customer', 'user', 'يختار مزوّداً'], ['SAWA', 'App', 'mobile', 'واجهة واحدة'],
    ['طلب تواصل', 'Contact Request', 'send', 'رقم مرجعي'], ['فريق SAWA', 'SAWA Team', 'headset', 'يتصل ويأخذ التفاصيل'],
    ['المزوّد / القاعة', 'Provider', 'store', 'نوصل الطلب'], ['التأكيد', 'Confirmation', 'badge', 'مع الطرفين'],
    ['العميل', 'Customer', 'heart', 'ونتابع معه'],
  ];
  const n = nodes.length, nw = 1.55, gap = (W - 2 * M - n * nw) / (n - 1);
  nodes.forEach(([t, en, ic, sub], i) => {
    const x = W - M - (i + 1) * nw - i * gap;
    anim(2 + i, 'zoom');
    const hl = i === 3;
    iconCircle(s, ic, 'white', hl ? C.gold : C.maroon, x + nw / 2 - 0.55, 2.35, 1.1, 0.44);
    T(s, t, { x: x - 0.15, y: 3.6, w: nw + 0.3, h: 0.45, fontSize: 17, bold: true, align: 'center' });
    T(s, en, { x: x - 0.15, y: 4.02, w: nw + 0.3, h: 0.35, fontSize: 12, color: C.gold, align: 'center', rtlMode: false });
    T(s, sub, { x: x - 0.15, y: 4.38, w: nw + 0.3, h: 0.6, fontSize: 13, color: C.grey, align: 'center' });
    if (i < n - 1) icon(s, 'arrow', 'gold', x - gap / 2 - 0.16, 2.74, 0.32);
  });
  anim(9, 'rise');
  card(s, 1.6, 5.35, W - 3.2, 1.25, C.maroon, { line: C.maroon });
  T(s, 'SAWA لا يترك العميل وحده بعد إرسال الطلب.', { x: 1.8, y: 5.35, w: W - 3.6, h: 1.25, fontSize: 30, bold: true, color: C.white, align: 'center', valign: 'middle' });
  pageNo(s, 12);
  notes(s, 'هذه قلب نموذج التشغيل بالمرحلة الأولى: الطلب يمر على فريق SAWA، الذي يتأكد من المتطلبات ويوصل الطلب للمزوّد ويتابع. لاحقاً يستطيع المزوّد استلام الطلبات المحوّلة داخل بوابته.');
}

// ═══ 13. Sara example ══════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'fade');
  kicker(s, 'مثال واقعي', M, 0.55, W - 2 * M);
  T(s, 'سارة تريد حفل تخرج خلال أسبوعين', { x: M, y: 0.9, w: W - 2 * M, h: 0.9, fontSize: 38, bold: true });
  // Without (right column, RTL first)
  const colW = 4.3;
  const rx = W - M - colW;
  anim(2, 'fade');
  T(s, 'بدون SAWA', { x: rx, y: 1.95, w: colW, h: 0.5, fontSize: 20, bold: true, color: C.grey });
  ['فتح Instagram', 'اتصال بالقاعات', 'اتصال بمصوّر', 'البحث عن ورد', 'البحث عن سيارات', 'مقارنة الأسعار يدوياً'].forEach((t, i) => {
    const y = 2.5 + i * 0.66;
    anim(3 + i, 'fade');
    card(s, rx, y, colW, 0.54, 'EFEAE3', { shadow: false, line: 'EFEAE3', r: 0.12 });
    icon(s, 'x', 'red', rx + colW - 0.44, y + 0.13, 0.28);
    T(s, t, { x: rx + 0.2, y, w: colW - 0.8, h: 0.54, fontSize: 16, color: C.grey, valign: 'middle' });
  });
  // With (left column)
  anim(10, 'fade');
  T(s, 'مع SAWA', { x: M, y: 1.95, w: colW, h: 0.5, fontSize: 20, bold: true, color: C.maroon });
  ['تختار حفل تخرج', 'تستعرض القاعات', 'تختار الخدمات', 'ترسل طلب تواصل', 'تحصل على رقم مرجعي', 'فريق SAWA يتابع معها'].forEach((t, i) => {
    const y = 2.5 + i * 0.66;
    anim(11 + i, 'rise');
    card(s, M, y, colW, 0.54, C.white, { r: 0.12 });
    s.addShape(pres.shapes.OVAL, { x: M + colW - 0.5, y: y + 0.08, w: 0.38, h: 0.38, fill: { color: C.maroon }, line: { color: C.maroon } });
    T(s, String(i + 1), { x: M + colW - 0.5, y: y + 0.08, w: 0.38, h: 0.38, fontSize: 12, bold: true, color: C.white, align: 'center', valign: 'middle', rtlMode: false });
    T(s, t, { x: M + 0.2, y, w: colW - 0.85, h: 0.54, fontSize: 16, bold: true, valign: 'middle' });
  });
  anim(9, 'flyup');
  phone(s, 'planner', W / 2 - 0.98, 2.0, 4.3);
  anim(17, 'zoom');
  T(s, 'من ساعات من البحث... إلى نقطة بداية واحدة.', { x: M, y: 6.6, w: W - 2 * M, h: 0.5, fontSize: 22, bold: true, color: C.maroon, align: 'center' });
  pageNo(s, 13);
  notes(s, 'الهاتف يعرض مخطط المناسبة: يرتب الخيارات بقواعد واضحة (السعة، المنطقة، الميزانية) ويشرح السبب، ونقول بصراحة إنه ليس ذكاءً اصطناعياً.');
}

// ═══ 14. Provider side ═════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'flyup');
  phone(s, 'dashboard', 1.1, 0.55, 6.4);
  anim(2, 'fade');
  kicker(s, 'بوابة مزوّد الخدمة', 5.5, 0.9, 7.2);
  T(s, 'SAWA ليس للعميل فقط', { x: 5.5, y: 1.25, w: 7.2, h: 0.9, fontSize: 40, bold: true });
  T(s, 'صاحب القاعة أو المصوّر يدير ملفه التجاري بنفسه.', { x: 5.5, y: 2.15, w: 7.2, h: 0.5, fontSize: 18, color: C.grey });
  const f = [['إنشاء حساب مزوّد', 'user'], ['إضافة بيانات النشاط', 'pen'], ['الخدمات والعروض', 'tag'], ['رفع الصور', 'upload'], ['إرسال للمراجعة', 'send'], ['بعد الموافقة: يظهر للزوار', 'eye']];
  f.forEach(([t, ic], i) => {
    const col = i % 2, row = Math.floor(i / 2);
    anim(3 + i, 'zoom');
    const cw = 3.45, x = W - M - (col + 1) * cw - col * 0.25, y = 2.95 + row * 1.08;
    card(s, x, y, cw, 0.88, i === 5 ? C.maroon : C.white, i === 5 ? { line: C.maroon } : {});
    iconCircle(s, ic, i === 5 ? 'maroon' : 'white', i === 5 ? C.champagne : C.maroon, x + cw - 0.75, y + 0.16, 0.56, 0.46);
    T(s, t, { x: x + 0.15, y, w: cw - 1.0, h: 0.88, fontSize: 16, bold: true, valign: 'middle', color: i === 5 ? C.white : C.charcoal });
  });
  anim(9, 'fade');
  T(s, 'أرقام اللوحة تجي من قاعدة البيانات، مو تقديرات. والشاشة هنا لحساب تجريبي.', { x: 5.5, y: 6.35, w: 7.2, h: 0.6, fontSize: 13, color: C.grey, italic: true });
  pageNo(s, 14);
  notes(s, 'الشاشة لحساب مثال (قاعة النخيل) بحالة "قيد المراجعة"، لذلك الأرقام صفر، وهذا مقصود: لا نعرض أرقاماً مخترعة.');
}

// ═══ 15. Data review & publishing ══════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'fade');
  kicker(s, 'جودة البيانات', M, 0.55, W - 2 * M);
  T(s, 'نراجع قبل ما ننشر', { x: M, y: 0.9, w: W - 2 * M, h: 0.9, fontSize: 40, bold: true });
  const stats = [['23', 'كتالوج مصدر'], ['15', 'مزوّد منشور'], ['0', 'معلومة مخمَّنة']];
  stats.forEach(([n, l], i) => {
    anim(2 + i, 'zoom');
    const w = 3.6, x = W - M - (i + 1) * w - i * 0.35;
    card(s, x, 1.95, w, 1.6, i === 2 ? C.maroon : C.white, i === 2 ? { line: C.maroon } : {});
    T(s, n, { x, y: 2.0, w, h: 1.0, fontSize: 54, bold: true, color: i === 2 ? C.white : C.maroon, align: 'center', rtlMode: false });
    T(s, l, { x, y: 2.95, w, h: 0.45, fontSize: 17, color: i === 2 ? C.champagne : C.grey, align: 'center' });
  });
  const steps = [['المصدر', 'file', 'كتالوج أو المزوّد'], ['استخراج منظّم', 'layers', 'اسم، منطقة، خدمات، صور'], ['مراجعة كل معلومة', 'listcheck', 'مصدرها؟ مؤكدة؟'], ['نشر', 'badge', 'يظهر للزوار']];
  const sw = 2.6, gap = (W - 2 * M - 4 * sw) / 3;
  steps.forEach(([t, ic, sub], i) => {
    const x = W - M - (i + 1) * sw - i * gap;
    anim(5 + i, 'rise');
    iconCircle(s, ic, 'white', i === 3 ? C.gold : C.maroon, x + sw / 2 - 0.4, 3.95, 0.8, 0.46);
    T(s, t, { x, y: 4.85, w: sw, h: 0.45, fontSize: 17, bold: true, align: 'center' });
    T(s, sub, { x, y: 5.28, w: sw, h: 0.45, fontSize: 13, color: C.grey, align: 'center' });
    if (i < 3) icon(s, 'arrow', 'gold', x - gap / 2 - 0.15, 4.2, 0.3);
  });
  const tags = [['من المصدر', C.maroon], ['غير مؤكد', C.gold], ['غير متوفر', C.grey]];
  tags.forEach(([t, c], i) => {
    anim(9, 'fade');
    const w = 2.1, x = W / 2 + 1.7 - i * (w + 0.25) - w / 2 - 0.3;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 6.1, w, h: 0.5, rectRadius: 0.25, fill: { color: C.white }, line: { color: c, width: 1.25 } });
    T(s, t, { x, y: 6.1, w, h: 0.5, fontSize: 15, bold: true, color: c, align: 'center', valign: 'middle' });
  });
  pageNo(s, 15);
  notes(s, 'كل حقل له حالة: من المصدر، غير مؤكد، غير متوفر. مثال: حساب إنستغرام ورد بغداد "غير مؤكد" لأن الكتالوج يذكر حسابين. ومزوّد جديد يمر: مسودة ← قيد المراجعة ← منشور.');
}

// ═══ 16. Business model ════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'fade');
  kicker(s, 'Business Model', 8.4, 1.0, 4.3);
  T(s, 'كيف يربح SAWA؟', { x: 8.4, y: 1.35, w: 4.3, h: 1.5, fontSize: 40, bold: true });
  T(s, 'هذي أفكار للدخل راح نجربها ويا السوق، مو أرقام نهائية.', { x: 8.4, y: 2.9, w: 4.3, h: 1.3, fontSize: 17, color: C.grey });
  anim(6, 'fade');
  card(s, 8.4, 4.55, 4.3, 1.55, C.soft, { shadow: false, line: C.soft });
  T(s, 'نبدي ويا المزودين ببلاش، ومن نثبت إن SAWA يجيب طلبات حقيقية نبدي نطلب اشتراك.', { x: 8.6, y: 4.55, w: 3.9, h: 1.55, fontSize: 16, color: C.maroon, valign: 'middle' });
  const m = [
    ['Commission', 'عمولة', 'نسبة من الحجوزات اللي تتم عن طريق SAWA', 'percent'],
    ['Featured', 'ظهور مميز', 'المزوّد يدفع حتى يطلع أول، ومكتوب عليه مميز', 'star'],
    ['Subscription', 'اشتراك شهري', 'مزايا إضافية وإحصائيات للمزوّد', 'crown'],
    ['Event Packages', 'باقات مناسبات', 'قاعة + ورد + تصوير + سيارات بباقة واحدة', 'gift'],
  ];
  m.forEach(([en, ar, d, ic], i) => {
    const col = i % 2, row = Math.floor(i / 2);
    anim(2 + i, 'zoom');
    const cw = 3.55, ch = 2.6, x = 7.8 - (col + 1) * cw - col * 0.3, y = 1.0 + row * (ch + 0.3);
    card(s, x, y, cw, ch, C.white);
    iconCircle(s, ic, 'white', C.maroon, x + cw - 1.05, y + 0.3, 0.75, 0.46);
    T(s, en, { x: x + 0.25, y: y + 0.35, w: 1.9, h: 0.4, fontSize: 13, color: C.gold, bold: true, align: 'left', rtlMode: false });
    T(s, ar, { x: x + 0.25, y: y + 1.15, w: cw - 0.5, h: 0.5, fontSize: 22, bold: true });
    T(s, d, { x: x + 0.25, y: y + 1.65, w: cw - 0.5, h: 0.8, fontSize: 14, color: C.grey });
  });
  pageNo(s, 16);
  notes(s, 'لا نذكر نسباً أو أرقام أرباح نهائية. الخطة: تجربة مجانية، ثم عمولة أو رسوم لكل طلب جدي، ثم اشتراكات وظهور مميز، وأي ظهور مدفوع يكون موسوماً بوضوح.');
}

// ═══ 17. Why SAWA ══════════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'dark_soft');
  anim(1, 'fade');
  T(s, 'لماذا SAWA؟', { x: M, y: 0.8, w: W - 2 * M, h: 1.0, fontSize: 44, bold: true, color: C.white, align: 'center' });
  const pts = [
    ['Local-first', 'مصمم للسوق المحلي', 'معمول للسوق العراقي، ونبدي من بغداد', 'pin'],
    ['Organized discovery', 'اكتشاف منظم', 'بدل البحث العشوائي', 'grid'],
    ['Human follow-up', 'متابعة بشرية', 'فريق SAWA يتابع كل طلب', 'headset'],
    ['Reviewed data', 'بيانات مراجعة', 'كل معلومة تمر بمراجعة قبل النشر', 'shield'],
  ];
  const cw = 2.8, gap = (W - 2 * M - 4 * cw) / 3;
  pts.forEach(([en, ar, d, ic], i) => {
    const x = W - M - (i + 1) * cw - i * gap;
    anim(2 + i, 'rise');
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 2.2, w: cw, h: 4.0, rectRadius: 0.25, fill: { color: C.white, transparency: 92 }, line: { color: C.champagne, width: 0.75, transparency: 55 } });
    iconCircle(s, ic, 'maroon', C.champagne, x + cw / 2 - 0.65, 2.6, 1.3, 0.46);
    T(s, en, { x, y: 4.15, w: cw, h: 0.4, fontSize: 14, bold: true, color: C.gold, align: 'center', rtlMode: false });
    T(s, ar, { x: x + 0.1, y: 4.55, w: cw - 0.2, h: 0.55, fontSize: 20, bold: true, color: C.white, align: 'center' });
    T(s, d, { x: x + 0.2, y: 5.15, w: cw - 0.4, h: 0.8, fontSize: 15, color: C.champagne, align: 'center' });
  });
  pageNo(s, 17, true);
  notes(s, 'أربع نقاط فقط. الأهم: المتابعة البشرية والبيانات المراجعة، هذا ما لا يوفره Instagram.');
}

// ═══ 18. Market ════════════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'fade');
  kicker(s, 'السوق والفرصة', M, 0.55, W - 2 * M);
  T(s, 'السوق موجود... لكن التجربة مجزأة', { x: M, y: 0.9, w: W - 2 * M, h: 0.9, fontSize: 38, bold: true });
  // needs (right)
  anim(2, 'fade');
  T(s, 'العميل يحتاج', { x: 9.2, y: 2.0, w: 3.5, h: 0.45, fontSize: 18, bold: true, color: C.maroon });
  [['قاعة', 'Venue', 'hall'], ['ورد', 'Flowers', 'rose'], ['تصوير', 'Photography', 'camera'], ['سيارات', 'Cars', 'car'], ['خدمات أخرى', 'Event Services', 'sparkle']].forEach(([ar, en, ic], i) => {
    anim(3 + i, 'rise');
    const y = 2.6 + i * 0.78;
    card(s, 9.2, y, 3.5, 0.62, C.white, { r: 0.31 });
    icon(s, ic, 'maroon', 12.2, y + 0.16, 0.3);
    T(s, ar, { x: 10.5, y, w: 1.6, h: 0.62, fontSize: 16, bold: true, valign: 'middle' });
    T(s, en, { x: 9.35, y, w: 1.3, h: 0.62, fontSize: 11, color: C.gold, valign: 'middle', align: 'left', rtlMode: false });
  });
  // scattered (middle)
  anim(8, 'fade');
  T(s, 'المعلومات موزعة بين', { x: 4.9, y: 2.0, w: 3.8, h: 0.45, fontSize: 18, bold: true, color: C.grey, align: 'center' });
  const sc = [['Instagram', 'instagram', 5.3, 2.75], ['Facebook', 'facebook', 7.2, 3.15], ['WhatsApp', 'whatsapp', 5.0, 4.05], ['اتصالات', 'phone', 7.1, 4.55], ['معارف', 'users', 5.8, 5.35]];
  sc.forEach(([t, ic, x, y], i) => {
    anim(9 + i, 'zoom');
    iconCircle(s, ic, 'grey', 'EFEAE3', x, y, 0.7, 0.5);
    T(s, t, { x: x - 0.35, y: y + 0.72, w: 1.4, h: 0.35, fontSize: 12, color: C.grey, align: 'center', rtlMode: t !== 'Instagram' && t !== 'Facebook' && t !== 'WhatsApp' });
  });
  // SAWA (left)
  anim(14, 'fade');
  icon(s, 'arrow', 'gold', 4.05, 4.0, 0.45);
  anim(15, 'zoom');
  s.addShape(pres.shapes.OVAL, { x: 0.9, y: 2.75, w: 2.9, h: 2.9, fill: { color: C.maroon }, line: { color: C.maroon }, shadow: { type: 'outer', color: '000000', opacity: 0.25, blur: 16, offset: 5, angle: 90 } });
  T(s, 'SAWA', { x: 0.9, y: 3.55, w: 2.9, h: 0.75, fontSize: 32, bold: true, color: C.white, align: 'center', charSpacing: 3, rtlMode: false });
  T(s, 'تجربة واحدة', { x: 0.9, y: 4.3, w: 2.9, h: 0.5, fontSize: 17, color: C.champagne, align: 'center' });
  pageNo(s, 18);
  notes(s, 'الفرصة ليست في اختراع طلب جديد، الناس أصلاً تبحث وتحجز. الفرصة في جمع التجربة المجزأة في مكان واحد موثوق.');
}

// ═══ 19. Future ════════════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'ivory');
  anim(1, 'fade');
  kicker(s, 'الرؤية المستقبلية', M, 0.55, W - 2 * M);
  T(s, 'اليوم نحل مشكلة البحث... غدًا نبني منصة المناسبات', { x: M, y: 0.9, w: W - 2 * M, h: 1.0, fontSize: 34, bold: true });
  const cols = [
    ['اليوم', 'متوفر الآن', C.maroon, [['اكتشاف منظم', 'search'], ['طلب تواصل ومتابعة', 'headset'], ['بوابة المزوّد', 'store']]],
    ['قريباً', 'الخطوة التالية', C.gold, [['مزودون أكثر: تجميل وسيارات', 'people'], ['حزم مناسبات كاملة', 'gift'], ['إدارة الطلبات', 'listcheck']]],
    ['المستقبل', 'رؤية أبعد', C.charcoal, [['التوسع لمدن أخرى', 'city'], ['مزايا للمزودين', 'chart'], ['Event planning ecosystem', 'rocket']]],
  ];
  const cw = 3.75, gap = (W - 2 * M - 3 * cw) / 2;
  anim(2, 'wipe');
  s.addShape(pres.shapes.LINE, { x: M + cw / 2, y: 2.55, w: W - 2 * M - cw, h: 0, line: { color: C.champagne, width: 2 } });
  cols.forEach(([t, sub, c, items], i) => {
    const x = W - M - (i + 1) * cw - i * gap;
    anim(3 + i, 'rise');
    s.addShape(pres.shapes.OVAL, { x: x + cw / 2 - 0.2, y: 2.35, w: 0.4, h: 0.4, fill: { color: c }, line: { color: C.white, width: 2 } });
    T(s, t, { x, y: 2.95, w: cw, h: 0.55, fontSize: 24, bold: true, color: c, align: 'center' });
    T(s, sub, { x, y: 3.45, w: cw, h: 0.4, fontSize: 13, color: C.grey, align: 'center' });
    items.forEach(([it, ic], j) => {
      const y = 4.05 + j * 0.85;
      card(s, x, y, cw, 0.68, C.white, { r: 0.14 });
      icon(s, ic, i === 0 ? 'maroon' : i === 1 ? 'gold' : 'charcoal', x + cw - 0.55, y + 0.18, 0.32);
      T(s, it, { x: x + 0.2, y, w: cw - 0.9, h: 0.68, fontSize: 15, bold: true, valign: 'middle', rtlMode: !it.startsWith('Event') });
    });
  });
  pageNo(s, 19);
  notes(s, 'نميّز بوضوح بين ما هو موجود اليوم (مبني ويعمل) وما هو مخطط. عندنا كتالوجات لمزودي التجميل والسيارات بانتظار المراجعة.');
}

// ═══ 20. Closing ═══════════════════════════════════════════════════════════
{
  const s = pres.addSlide(); bg(s, 'dark');
  anim(1, 'flyup');
  phone(s, 'home_halls', 1.4, 0.5, 6.5);
  anim(2, 'zoom');
  T(s, 'SAWA', { x: 5.6, y: 1.4, w: 7.1, h: 1.6, fontSize: 110, bold: true, color: C.white, charSpacing: 8, rtlMode: false });
  anim(3, 'fade');
  T(s, 'كل ما تحتاجه مناسبتك... بمكان واحد.', { x: 5.6, y: 3.15, w: 7.1, h: 0.8, fontSize: 30, bold: true, color: C.champagne });
  const names = ['Baneen Waleed', 'Hawraa Hassan', 'Fanar Hassan'];
  names.forEach((n, i) => {
    anim(4 + i, 'rise');
    const w = 2.2, x = W - M - (i + 1) * w - i * 0.2;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 4.75, w, h: 0.62, rectRadius: 0.31, fill: { color: C.white, transparency: 88 }, line: { color: C.champagne, width: 1 } });
    T(s, n, { x, y: 4.75, w, h: 0.62, fontSize: 16, bold: true, color: C.white, align: 'center', valign: 'middle', rtlMode: false });
  });
  anim(7, 'fade');
  T(s, 'شكراً إلكم، وننتظر أسئلتكم', { x: 5.6, y: 5.8, w: 7.1, h: 0.5, fontSize: 18, color: C.champagne });
  notes(s, 'ختام: نكرر الجملة الأساسية ونفتح باب الأسئلة. أسئلة متوقعة: التحقق من البيانات، لماذا يمر الطلب على فريق SAWA، نموذج الربح، حماية أرقام العملاء.');
}

pres.writeFile({ fileName: OUT }).then((f) => console.log('Wrote', f));
