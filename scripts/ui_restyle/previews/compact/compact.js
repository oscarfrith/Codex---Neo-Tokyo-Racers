/* Pulse preview helpers, Compact class (phones, landscape). Review 1 rework (2026-10-09):
   small edge clusters, slim garage rail. Review 2 (2026-10-09): free-roam buttons top centre, always-visible
   stat block, tier colours. Review 3 (2026-10-09): Classic touch controls restyled, gradient ring and gauge images.
   Uses ../shared/pulse.js only for P.ic, P.scene, P.route, P.medal, P.toast, P.fact, P.sil, P.layer, P.reveal and P.gaugeArt; every phone composition lives here.
   Device size = window size (or ?w=&h=). Scale = clamp(height / 390, 0.85, 1.10), applied with CSS
   zoom to the .cx stage, which is laid out in Compact design units inside the device safe area.
   C.measure() rasterises every painted rectangle (fills, borders, images, text runs) onto the
   device grid and prints the share of the screen the UI covers. */
(function () {
  const C = {};
  const ic = P.ic;

  C.metrics = () => {
    const q = new URLSearchParams(location.search);
    const w = +q.get("w") || window.innerWidth, h = +q.get("h") || window.innerHeight;   // ?w=568&h=320 pins the device size
    const notch = w / h > 2.0;                       // 19.5:9 phones have a notch and a home bar
    const L = notch ? (h >= 420 ? 59 : 47) : 0, R = L, B = notch ? 21 : 0;
    const s = Math.max(0.85, Math.min(1.10, h / 390));
    const t = Math.max(48, 48 / s), g = Math.max(8, 8 / s);
    /* steering arrow width: 52 units, narrowed (never under one target) so the block stays left of the centre 60% */
    const sw = Math.max(t, Math.min(52, ((0.2 * w - L) / s - 8 - g) / 2));
    return { w, h, L, R, B, s, W: (w - L - R) / s, H: (h - B) / s, t, g, sw, tbw: 120 / s, tbh: 52 / s };
  };

  /* o: {scene, scrim:"hud"|"garage"|"menu"|"", dim, under:html, foot:bool, title, bg} */
  C.page = (o, html) => {
    const m = C.metrics();
    const vars = `--t:${m.t.toFixed(2)}px;--g:${m.g.toFixed(2)}px;--sw:${m.sw.toFixed(2)}px;--tbw:${m.tbw.toFixed(2)}px;--tbh:${m.tbh.toFixed(2)}px`;
    const stage = (inner) => `<div class="safe" style="left:${m.L}px;width:${m.w - m.L - m.R}px;height:${m.h - m.B}px"><div class="cx" style="zoom:${m.s};width:${m.W.toFixed(2)}px;height:${m.H.toFixed(2)}px;${vars}">${inner}</div></div>`;
    const tag = `<div class="tag" id="covtag" style="left:${m.L + 4}px;bottom:${m.B ? 5 : 1}px">${m.L ? `safe area ${m.L} / ${m.R} / ${m.B}` : "no insets"} &middot; ${m.w}x${m.h} &middot; scale ${m.s.toFixed(2)}</div>`;
    const guides = `<div class="guide-safe">` +
      (m.L ? `<div class="edge" style="left:0;top:0;bottom:0;width:${m.L}px"></div><div class="edge" style="right:0;top:0;bottom:0;width:${m.R}px"></div><div class="edge" style="left:${m.L}px;right:${m.R}px;bottom:0;height:${m.B}px"></div>` +
        `<div class="line" style="left:${m.L}px;top:0;bottom:0;border-left-width:1px"></div><div class="line" style="right:${m.R}px;top:0;bottom:0;border-left-width:1px"></div><div class="line" style="left:${m.L}px;right:${m.R}px;bottom:${m.B}px;border-top-width:1px"></div>` +
        `<div class="bezel"></div><div class="notch"></div><div class="home"></div>` : "") + tag +
      `</div><div class="guide-top" style="left:${m.L + 8}px"><i></i><i></i><b>Roblox top bar</b></div>` +
      (o.foot ? `<div class="guide-rbx" style="left:${m.L + 22}px;bottom:${m.B + 16}px;width:112px;height:112px"><div class="guide-rbx inner" style="position:static;width:48px;height:48px"></div></div>` +
        `<div class="guide-rbx" style="left:${m.L + 30}px;bottom:${m.B + 132}px;width:96px;height:14px;border:0;background:none">Roblox thumbstick</div>` +
        `<div class="guide-rbx" style="right:${m.R + 26}px;bottom:${m.B + 26}px;width:72px;height:72px">Roblox<br>jump</div>` : "");
    const scrim = o.scrim ? `<div class="scrim-${o.scrim}"></div>` : "";
    document.body.innerHTML = `<div class="device" style="width:${m.w}px;height:${m.h}px">${o.bg ?? P.scene(o.scene || "city", "", o.dim)}${scrim}` +
      (o.under ? stage(o.under) + `<div class="scrim-modal"></div>` : "") + stage(html) + guides + `</div>`;
    document.title = o.title || document.title;
    const run = () => setTimeout(() => C.measure(o), 60);
    (document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve()).then(run);
  };

  /* ---- coverage ---------------------------------------------------------- */
  const alpha = (c) => { const m = /rgba?\(([^)]+)\)/.exec(c || ""); if (!m) return 0; const p = m[1].split(/[,\/\s]+/).filter(Boolean); return p.length > 3 ? parseFloat(p[3]) : 1; };
  C.measure = (o = {}) => {
    const m = C.metrics(), W = m.w, H = m.h, grid = new Uint8Array(W * H);
    let minTs = 999, minEl = "";
    document.querySelectorAll(".cx").forEach((cx) => {
      const cr = cx.getBoundingClientRect(), k = (m.w - m.L - m.R) / cr.width;      // k = 1 when rects are already in device px
      const map = (r) => ({ l: m.L + (r.left - cr.left) * k, t: (r.top - cr.top) * k, r: m.L + (r.right - cr.left) * k, b: (r.bottom - cr.top) * k });
      const clipOf = (el) => {
        let c = { l: 0, t: 0, r: W, b: H };
        for (let p = el.parentElement; p && p !== cx; p = p.parentElement) {
          if (getComputedStyle(p).overflow !== "visible") { const q = map(p.getBoundingClientRect()); c = { l: Math.max(c.l, q.l), t: Math.max(c.t, q.t), r: Math.min(c.r, q.r), b: Math.min(c.b, q.b) }; }
        }
        return c;
      };
      const fill = (r, c, v) => {
        const x0 = Math.max(0, Math.round(Math.max(r.l, c.l))), x1 = Math.min(W, Math.round(Math.min(r.r, c.r)));
        const y0 = Math.max(0, Math.round(Math.max(r.t, c.t))), y1 = Math.min(H, Math.round(Math.min(r.b, c.b)));
        for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) grid[y * W + x] |= v;
      };
      cx.querySelectorAll("*").forEach((el) => {
        const svg = el.closest("svg");
        if ((svg && svg !== el) || el.closest("[data-nocov]")) return;
        const cs = getComputedStyle(el);
        if (cs.display === "none" || cs.visibility === "hidden") return;
        for (let p = el; p && p !== cx; p = p.parentElement) if (parseFloat(getComputedStyle(p).opacity) < 0.05) return;
        const v = el.closest("[data-x]") ? 2 : 1;                                   // 2 = exempt from the centre test (speed readout)
        const clip = clipOf(el);
        const border = ["Top", "Right", "Bottom", "Left"].some((s) => parseFloat(cs["border" + s + "Width"]) > 0 && cs["border" + s + "Style"] !== "none" && alpha(cs["border" + s + "Color"]) > 0.04);
        if (el === svg || el.tagName === "IMG" || alpha(cs.backgroundColor) > 0.04 || cs.backgroundImage !== "none" || border) fill(map(el.getBoundingClientRect()), clip, v);
        el.childNodes.forEach((n) => {
          if (n.nodeType !== 3 || !n.nodeValue.trim()) return;
          const rg = document.createRange(); rg.selectNodeContents(n);
          for (const r of rg.getClientRects()) fill(map(r), clip, v);
          if (!el.closest(".num") && !el.closest("[data-img]")) { const ts = parseFloat(cs.fontSize) * 1.2 * m.s; if (ts < minTs) { minTs = ts; minEl = n.nodeValue.trim().slice(0, 18); } }
        });
      });
    });
    let all = 0, centre = 0;
    const cx0 = Math.round(W * 0.2), cx1 = Math.round(W * 0.8), cy0 = Math.round(H * 0.2), cy1 = Math.round(H * 0.8);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const v = grid[y * W + x]; if (v) { all++; if ((v & 1) && x >= cx0 && x < cx1 && y >= cy0 && y < cy1) centre++; } }
    const res = { ui: +(100 * all / (W * H)).toFixed(1), centre: +(100 * centre / ((cx1 - cx0) * (cy1 - cy0))).toFixed(1), minTextSize: +minTs.toFixed(1), minText: minEl, w: W, h: H };
    document.documentElement.dataset.cov = JSON.stringify(res);
    const tag = document.getElementById("covtag");
    if (tag) tag.innerHTML += ` &middot; <b>UI covers ${res.ui}% of the screen</b> (${(100 - res.ui).toFixed(1)}% clear) &middot; centre 60x60: ${res.centre}% &middot; smallest TextSize ${res.minTextSize}`;
    if (new URLSearchParams(location.search).get("debug")) {
      const cv = document.createElement("canvas"); cv.width = W; cv.height = H; cv.style.cssText = "position:absolute;left:0;top:0;pointer-events:none";
      const g = cv.getContext("2d"), im = g.createImageData(W, H);
      for (let i = 0; i < W * H; i++) if (grid[i]) { im.data[i * 4] = grid[i] & 1 ? 255 : 34; im.data[i * 4 + 1] = grid[i] & 1 ? 45 : 228; im.data[i * 4 + 2] = grid[i] & 1 ? 149 : 255; im.data[i * 4 + 3] = 110; }
      g.putImageData(im, 0, 0); g.strokeStyle = "#FFE433"; g.setLineDash([4, 3]); g.strokeRect(cx0 + .5, cy0 + .5, cx1 - cx0, cy1 - cy0);
      document.querySelector(".device").appendChild(cv);
    }
  };

  /* ---- pieces ------------------------------------------------------------ */
  C.btn = (label, icon, variant = "") => `<div class="btn ${variant}">${icon ? ic(icon) : ""}<span>${label}</span>${/\b(main|buy)\b/.test(variant) && !/nochev/.test(variant) ? `<span>&raquo;</span>` : ""}</div>`;
  C.ibtn = (icon, cls = "") => `<div class="btn icon ${cls}">${ic(icon)}</div>`;
  C.actions = (btns, cls = "") => `<div class="c-actions ${cls}">${btns.join("")}</div>`;
  C.title = (text, sub) => `<div class="c-title"><div class="titlemark"></div>${text ? `<div class="t-title shadow">${text}</div>` : ""}${sub ? `<div class="sub t-label c-2 shadow">${sub}</div>` : ""}</div>`;
  C.tabs = (items, style = "") => `<div class="c-tabs" style="${style}">` + items.map((t) => `<div class="c-tab shadow ${t.on ? "on" : ""}">${t.i ? ic(t.i) : ""}${t.l}</div>`).join("") + `</div>`;
  C.tr = (tier, pi) => `<span class="c-tr" data-t="${tier}">${tier}${pi ? ` ${pi}` : ""}</span>`;
  /* one-line status strip, top-right. o: {car:{name,tier,pi,open,fixed}, garage:"3 / 4", cash} */
  C.strip = (o = {}) => `<div class="c-strip">` +
    (o.car ? `<div class="c-seg ${o.car.open ? "on" : ""}">${o.car.name ? `<span>${o.car.name}</span>` : ""}${C.tr(o.car.tier, o.car.pi)}${o.car.fixed ? "" : ic(o.car.open ? "up" : "down", "chev")}</div>` : "") +
    (o.garage ? `<div class="c-seg">${ic("garage")}<span>${o.garage}</span></div>` : "") +
    `<div class="c-cash">${ic("coin")}<span>${o.cash || "$3.61M"}</span></div></div>`;
  /* expanded stat card (the strip's car segment opened). stats: [[label, value, gain]] */
  C.stats = (sub, stats) => `<div class="c-stats">${sub ? `<div class="t-label c-2" style="margin-bottom:4px">${sub}</div>` : ""}` + stats.map((s) => {
    const gain = s[2] || 0, n = 8, base = Math.round((s[1] - Math.max(gain, 0)) / 100 * n), gseg = gain ? Math.max(1, Math.round(s[1] / 100 * n) - base) : 0;
    return `<div class="c-stat"><span class="lab t-label">${s[0]}</span><span class="bar"><i style="width:${base * 6}px"></i>${gain ? `<i class="gain" style="width:${gseg * 6}px"></i>` : ""}</span>` +
      `<span class="val ${gain > 0 ? "c-cyan" : ""}">${s[1]}</span><span class="gn">${gain ? `<span class="chip cyan">+${gain}</span>` : ""}</span></div>`;
  }).join("") + `</div>`;
  /* always-visible stat block (review 2). o: {tier, pi, name, price, sub, stats:[[label, value, gain]]} */
  C.statblock = (o) => {
    const rows = C.stats("", o.stats).replace(/^<div class="c-stats">/, "").replace(/<\/div>$/, "");
    return `<div class="c-sb ${o.stats.some((s) => s[2]) ? "g" : ""}"><div class="hd">${C.tr(o.tier, o.pi)}<span>${o.name}</span></div>` +
      (o.price ? `<div class="pr"><span class="t-label c-2">PRICE</span><span class="chip yellow">${o.price}</span></div>` : "") +
      (o.sub ? `<div class="sub t-label c-2">${o.sub}</div>` : "") + rows + `</div>`;
  };
  /* rail tile: image plus one line. o: {name, vis, sel, tick, price, unaff, corner, tier, locked, cls} */
  C.tile = (o) => `<div class="ct ${o.sel ? "sel" : ""} ${o.locked ? "locked" : ""} ${o.cls || ""}">${o.tier ? `<span class="tl">${C.tr(o.tier)}</span>` : ""}` +
    (o.price ? `<span class="cr chip price ${o.unaff ? "unaff" : ""}">${o.price}</span>` : o.corner ? `<span class="cr chip">${o.corner}</span>` : o.tick ? `<span class="cr tk">${ic("tick")}</span>` : "") +
    `<div class="vis">${o.locked ? ic("lock") : (o.vis || P.sil(""))}</div><div class="nm">${o.name}</div></div>`;
  C.modal = (title, body, btns, style = "", extra = "") => `<div class="modal" style="${style}"><div class="mhead"><div class="titlemark"></div><div class="t-sect">${title}</div>${extra}</div><div class="mbody">${body}</div>${btns ? `<div class="mbtns">${btns.join("")}</div>` : ""}</div>`;
  /* modal slot: the block is centred in the area to the right of the Roblox top bar */
  C.modalSlot = (inner) => `<div class="abs" style="left:var(--tbw);right:var(--m);top:var(--m);bottom:var(--m);display:flex;align-items:center;justify-content:center">${inner}</div>`;

  /* minimap 92 dp with the driver-rank arc around its upper-left edge; rank number at the arc's start.
     Review 3: the ring and the rank arc are the baked gradient images (minimap_ring_gradient.png,
     rank_arc_gradient.png), the same files and colours as the desktop HUD. */
  C.minimap = (rank = 6, p = 0.42) => {
    const c = 56, R = 51, pt = (a) => [(c + R * Math.cos(a * Math.PI / 180)).toFixed(1), (c + R * Math.sin(a * Math.PI / 180)).toFixed(1)];
    const A0 = 165, A1 = 285, [x0, y0] = pt(A0), X = c + 8, ring = 46.5 * 2 * 512 / 480, arc = 52.5 * 2 * 256 / 244;
    const box = `viewBox="-8 0 112 104" width="112" height="104" style="position:absolute;left:0;top:0;overflow:visible"`;
    return `<div class="c-map"><svg ${box}>
      <defs><clipPath id="mm"><circle cx="${c}" cy="${c}" r="45"/></clipPath></defs>
      <g clip-path="url(#mm)"><g transform="translate(${c - 45} ${c - 45}) scale(0.3)">
        <rect width="300" height="300" fill="#1b1932"/>
        <g stroke="#5a5680" stroke-width="22" fill="none"><path d="M-10 70 L320 240"/><path d="M190 -10 V320"/><path d="M90 320 L260 20"/><path d="M-10 222 H320" stroke-width="10"/></g>
        <path d="M148 168 L206 40" stroke="#FF2D95" stroke-width="10" fill="none"/>
        <g fill="#F3F0FF" stroke="#07060D" stroke-width="5"><circle cx="100" cy="92" r="11"/><circle cx="206" cy="124" r="11"/><circle cx="182" cy="226" r="11"/></g>
        <path d="M148 138 L174 196 L148 182 L122 196 Z" fill="#F3F0FF" transform="rotate(20 148 170)"/></g></g></svg>` +
      P.layer("minimap_ring_gradient.png", ring, X, c) +
      P.layer("rank_arc_gradient.png", arc, X, c, "opacity:.25;" + P.reveal(A0, A1 - A0)) +
      P.layer("rank_arc_gradient.png", arc, X, c, P.reveal(A0, (A1 - A0) * p)) + `<svg data-nocov ${box}>
      <circle cx="${x0}" cy="${y0}" r="9.5" fill="#07060D" stroke="#9A3DFF" stroke-width="1.5"/>
      <text x="${x0 - 0.6}" y="${+y0 + 4.8}" text-anchor="middle" font-family="Barlow" font-style="italic" font-weight="800" font-size="13.8" fill="#F3F0FF">${rank}</text>
      <circle cx="${c}" cy="97" r="6.5" fill="#07060D" stroke="rgba(243,240,255,.3)" stroke-width="1"/>
      <text x="${c - 0.4}" y="100.2" text-anchor="middle" font-family="Barlow" font-style="italic" font-weight="800" font-size="9" fill="#F3F0FF">N</text></svg></div>`;
  };

  /* speed readout, review 3: the desktop gauge in small (the same five images, 92 dp across): image digits in the
     middle, boost as the inner arc. The .cov span is the painted area the coverage measure counts. */
  C.speed = (speed, boost) => `<div class="c-speed" data-x><span class="cov"></span>${P.gaugeArt(92, Math.min(1, speed / 240), boost)}
      <div class="num n">${speed}</div><div class="t-label c-2 u">MPH</div></div>`;

  /* touch drive controls, review 3: the Classic controls restyled (square Slate plate, gradient outline, Classic
     pictograms). Each is one baked image; the frames show the generator's own SVG (../../assets/touch_svg/).
     C.ctl(name, state, charge) draws one control; state = "idle" | "on" (pressed) | "off" (disabled).
     .k is the hit box (dashed on the sheet), .art is the plate (what the coverage measure counts), the image
     overhangs it by the glow margin. Right-hand turn and drift are the left images mirrored. */
  const TOUCH = { turn: [52, 52], drift: [52, 52], accelerate: [72, 100], brake: [76, 64], boost: [48, 48] };   // plate dp, as in touch.json
  C.ctl = (name, st = "idle", charge = 100) => {
    const kind = { TurnLeft: "turn", TurnRight: "turn", DriftLeft: "drift", DriftRight: "drift", Accelerator: "accelerate", Brake: "brake", Boost: "boost" }[name];
    const side = /Left$/.test(name) ? " l" : /Right$/.test(name) ? " r" : "", [w, h] = TOUCH[kind], v = Math.max(w, h) + 10;
    const img = `<img data-nocov src="../../assets/touch_svg/touch_${kind}${st === "on" ? "_pressed" : ""}.svg" style="width:${(100 * v / w).toFixed(3)}%;${/Right$/.test(name) ? "transform:translate(-50%,-50%) scaleX(-1);" : ""}${st === "off" ? "opacity:.38;" : ""}">`;
    /* boost charge: rank_arc_gradient.png in the same frame, revealed clockwise from 12 o'clock */
    const ring = kind === "boost" ? `<span class="chg">${P.layer("rank_arc_gradient.png", 60, 30, 30, "opacity:.25;")}${st === "off" ? "" : P.layer("rank_arc_gradient.png", 60, 30, 30, P.reveal(270, 3.6 * charge))}</span>` : "";
    return `<div class="k hit ${kind}${side}"><span class="art">${img}${ring}</span></div>`;
  };
  /* o: {on:[names], off:bool, boost:charge %} */
  C.touch = (o = {}) => {
    const k = (n) => C.ctl(n, o.off ? "off" : (o.on || []).includes(n) ? "on" : "idle", o.boost ?? 100);
    return `<div class="tc-left">${k("Boost")}${k("DriftLeft")}${k("DriftRight")}${k("TurnLeft")}${k("TurnRight")}</div>
      <div class="tc-right">${k("Brake")}${k("Accelerator")}</div>`;
  };
  C.exit = () => `<div class="c-exit hit"><div class="tc">${ic("exit")}<span>EXIT</span></div></div>`;

  /* free-roam HUD. o: {mode:"foot"|"drive", open:index, speed, boost, on:[...], noExit, panel:bool} */
  C.nav = (open) => `<div class="c-nav">` + ["car", "garage", "flag", "wrench", "sliders"].map((n, i) => `<div class="nb hit"><div class="nbv ${i === open ? "on" : ""}">${ic(n)}</div></div>`).join("") + `</div>`;
  C.hud = (o = {}) => {
    const drive = o.mode === "drive";
    return `<div class="${o.panel ? "c-shift" : ""}">` + (o.panel ? "" : C.minimap()) + C.nav(o.open) +
      `<div class="c-hudcash c-cash">${ic("coin")}<span>${o.cash || "$3.61M"}</span></div></div>` +
      (drive ? C.speed(o.speed ?? 0, o.boost ?? 100) + (o.noExit ? "" : C.exit()) + C.touch({ on: o.on, boost: o.boost ?? 100 }) : "");
  };

  /* garage shell. o: {title, tabs, tabsExtra, strip, stats, head, rail, railCls, actions} */
  C.garage = (o) => C.title(o.title) + C.tabs(o.tabs) + (o.tabsExtra || "") + C.strip(o.strip) + (o.stats || "") +
    `<div class="c-railhead">${o.head}</div>` + C.actions(o.actions) +
    `<div class="c-rail ${o.railCls || ""}">${o.rail}</div>`;

  C.STATS = [["SPEED", 80], ["ACCEL", 74], ["HANDLING", 63], ["DRIFT", 61], ["BRAKING", 62], ["BOOST", 61]];
  window.C = C;
})();
