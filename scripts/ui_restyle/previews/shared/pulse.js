/* Pulse preview helpers (regular class). Builds kit markup from data so every frame
   uses the same component markup. Stage is 1920x1080 design pixels; the plan 3.2 scale
   (min(h/1080, w/1600), clamped 0.667..2, snapped down to 1/24) is applied with CSS zoom. */
(function () {
  const P = {};
  const esc = (s) => String(s);
  P.ic = (n, cls = "") => `<i class="ic ${n} ${cls}"></i>`;

  P.scale = () => {
    const w = window.innerWidth, h = window.innerHeight;
    let s = Math.min(h / 1080, w / 1600);
    s = Math.max(0.667, Math.min(2, s));
    s = Math.floor(s * 24 + 0.02) / 24;
    return s;
  };
  P.page = (html, opts = {}) => {
    const st = document.createElement("div");
    st.className = "stage " + (opts.cls || "");
    st.innerHTML = html;
    document.body.appendChild(st);
    const fit = () => { st.style.zoom = opts.noscale ? 1 : P.scale(); };
    fit(); window.addEventListener("resize", fit);
  };

  /* scene: name = city | garage | menu | race | dealer | flat */
  P.scene = (name, tag, dim) => {
    const bg = name === "flat" ? "" : `style="background-image:url(../shared/bg/${name}.jpg)"`;
    return `<div class="scene ${name === "flat" ? "flat" : ""}" ${bg}></div>` +
      (dim ? `<div class="abs" style="inset:0;background:rgba(7,6,13,${dim})"></div>` : "") +
      (tag ? `<div class="scene-tag">${tag}</div>` : "");
  };

  P.title = (text, sub) =>
    `<div class="title"><div class="titlemark"></div><div class="t-title shadow">${text}</div>${sub ? `<div class="sub t-label c-2 shadow">${sub}</div>` : ""}</div>`;

  P.tabs = (items, cls = "") =>
    `<div class="tabs ${cls}">` + items.map((t) =>
      `<div class="tab t-tab ${t.on ? "on" : ""} ${t.locked ? "locked" : ""} ${t.focus ? "focus" : ""}">${t.i ? P.ic(t.i) : ""}${t.l}</div>`).join("") + `</div>`;

  /* status cluster. o: {hud, garage:"3 / 4", tier:"S", rating:939, rank:6, cash:"$3,613,696", plus, static} */
  P.status = (o = {}) => {
    const first = o.garage
      ? `<div class="seg">${P.ic("garage")}<span class="t-status">${o.garage}</span>${o.plus ? `<span class="plusbtn">${P.ic("plus")}</span>` : ""}</div>`
      : o.tier ? `<div class="seg">${P.ic("car")}<span class="tier">${o.tier}</span><span class="t-status">${o.rating}</span></div>`
      : `<div class="seg">${P.ic("person")}<span class="t-status">ON FOOT</span></div>`;
    return `<div class="status ${o.hud ? "hud" : ""} ${o.static ? "static" : ""}">${first}` +
      `<div class="seg"><span class="rankring">${o.rank ?? 6}</span></div>` +
      `<div class="cash fixed">${P.ic("coin")}<span class="t-status">${o.cash || "$3,613,696"}</span>${o.plus ? `<span class="plusbtn">${P.ic("plus")}</span>` : ""}</div></div>`;
  };

  /* tile. o: {cls, idx, variant, tier, rating, corner:{t,cls}, price, unaff, vis, sub, name, t7, sel, locked, two, w, noimg} */
  P.tile = (o) => {
    const cls = ["tile", o.t7 ? "t7" : "", o.sel ? "sel" : "", o.locked ? "locked" : "", o.two ? "two" : "", o.noimg ? "noimg" : "", o.cls || ""].join(" ");
    let h = `<div class="${cls}" ${o.w ? `style="width:${o.w}px"` : ""}>`;
    if (o.idx) h += `<div class="idx t-label">${o.idx}</div>`;
    if (o.variant) h += `<div class="var chip ${o.sel ? "ink" : ""}">${o.variant}</div>`;
    if (o.tier) h += `<div class="var">${o.rating ? `<span class="tierrating"><span>${o.tier}</span><span>${o.rating}</span></span>` : `<span class="tier">${o.tier}</span>`}</div>`;
    if (o.price) h += `<div class="corner chip price ${o.unaff ? "unaff" : ""}">${o.price}</div>`;
    else if (o.corner) h += `<div class="corner chip ${o.corner.cls || ""}">${o.corner.t}</div>`;
    h += `<div class="vis">${o.noimg ? "" : (o.vis || `<div class="sil"></div>`)}</div>`;
    if (o.locked) h += P.ic("lock", "lockicon");
    if (o.sub) h += `<div class="sub t-label">${o.sub}</div>`;
    h += `<div class="name ${o.t7 ? "t-tile7" : "t-tile"}" style="white-space:normal">${o.name}</div></div>`;
    return h;
  };
  P.sil = (kind = "") => `<div class="sil ${kind}"></div>`;

  P.railhead = (head, extra = "") => `<div class="railhead"><div class="t-sect shadow">${head}</div>${extra}</div>`;
  P.sw = (opts, cls = "") => `<div class="switch ${cls}">` + opts.map((o) => `<div class="opt t-tab ${o.on ? "on" : ""}">${o.l}</div>`).join("") + `</div>`;
  P.segswitch = (opts, style = "") => `<div class="segswitch" style="${style}">` + opts.map((o) => `<div class="opt t-value ${o.on ? "on" : ""}">${o.l}</div>`).join("") + `</div>`;

  /* button. variant: "" | main | buy | danger ; extra classes: focus dis sm md */
  P.btn = (label, icon, variant = "") =>
    `<div class="btn ${variant}">${icon ? P.ic(icon) : ""}<span>${label}</span>${/\bmain\b|\bbuy\b/.test(variant) && !/nochev/.test(variant) ? `<span>&raquo;</span>` : ""}</div>`;
  P.btnrow = (btns, cls = "") => `<div class="btnrow ${cls}">${btns.join("")}</div>`;

  P.segbar = (v, gain = 0, n = 16, cls = "") => {
    const base = Math.round((Math.min(v, v + gain)) / 100 * n);
    const g = Math.round((Math.max(v, v + gain)) / 100 * n) - base;
    const wpx = (k) => k * 13;
    return `<div class="segbar ${cls}" style="width:${n * 13 - 3}px"><i style="width:${wpx(base)}px"></i>${g > 0 ? `<i class="${gain > 0 ? "gain" : "loss"}" style="width:${wpx(g) - (base + g >= n ? 3 : 0)}px"></i>` : ""}</div>`;
  };
  /* stat panel. o: {name, badge, sub:[[label,value]], stats:[[label,value,gain]], style, extra} */
  P.statpanel = (o) => {
    const anyGain = o.stats.some((s) => s[2]);
    let h = `<div class="statpanel panel ${o.slot ? "slot" : ""}" style="${o.style || ""}"><div class="head"><div class="t-sect" style="font-size:46px">${o.name}</div>${o.badge ? `<span class="tierrating">${o.badge}</span>` : ""}</div>`;
    (o.sub || []).forEach((s) => { h += `<div class="subline"><span class="t-label">${s[0]}</span><span class="t-body" style="line-height:1">${s[1] || ""}</span></div>`; });
    h += `<div style="height:10px"></div>`;
    o.stats.forEach((s) => {
      const gain = s[2] || 0;
      h += `<div class="stat"><span class="lab t-value" style="font-size:24px">${s[0]}</span>${P.segbar(s[1] - Math.max(gain, 0), gain, anyGain ? 13 : 16)}` +
        `<span class="val t-value" style="margin-left:auto">${s[1]}</span>` +
        (anyGain ? (gain ? `<span class="chip gain ${gain > 0 ? "cyan" : "pink"}">${P.ic(gain > 0 ? "up" : "down")}${gain > 0 ? "+" : ""}${gain}</span>` : `<span style="width:66px;flex:none"></span>`) : "") + `</div>`;
    });
    return h + (o.extra || "") + `</div>`;
  };

  P.fact = (icon, label, value, vcls = "") => `<div class="fact">${icon ? P.ic(icon) : ""}<span class="t-label c-2">${label}</span><span class="v t-value ${vcls}">${value}</span></div>`;

  /* route line drawings (images in Roblox) */
  const ROUTES = {
    loop: "M20 150 Q20 128 44 128 H130 Q168 128 196 104 Q216 86 216 60 V34 Q216 14 238 14 H286 Q306 14 306 34 V92 Q306 110 326 110 H374 Q396 110 396 132 V170 Q396 190 374 190 H324 Q304 190 304 170 V158 Q304 142 286 142 H262 Q244 142 244 160 V170 Q244 190 222 190 H44 Q20 190 20 168 Z",
    sprint: "M20 120 L70 70 H190 L170 110 H260 L300 60 H400",
    canal: "M40 30 H250 Q290 30 290 62 Q290 92 250 92 H200 Q178 92 178 112 Q178 132 200 132 H330 Q372 132 372 164 Q372 192 330 192 H70 Q40 192 40 160 Z",
  };
  P.route = (kind = "loop", color = "var(--cyan)", w = 420, sw = 10, dot = "var(--pink)") => {
    const pts = { loop: [196, 104], sprint: [20, 120], canal: [40, 100] }[kind];
    return `<svg viewBox="0 0 420 206" width="${w}" height="${Math.round(w * 206 / 420)}" style="display:block"><path d="${ROUTES[kind]}" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linejoin="round"/>${dot ? `<circle cx="${pts[0]}" cy="${pts[1]}" r="${sw * 1.1}" fill="${dot}"/>` : ""}</svg>`;
  };

  /* minimap (round CanvasGroup + ring image in Roblox). o:{label, style, route} */
  /* review 1: the minimap sits 18 px inside the HUD margin so the rank arc's outer edge lands on the margin.
     rank arc = ring image revealed by a gradient in Roblox: constant 10 px width, 8 px outside the map ring,
     from 9 o'clock to 12 o'clock, filled clockwise to the XP fraction; rank number outside it at about 10 o'clock. */
  P.rankarc = (o = {}) => {
    const x = o.x ?? 58, b = o.b ?? 80, C = 177.5, R = 166.5, f = Math.max(0, Math.min(1, (o.p ?? 22) / 100));
    const pt = (a, r = R) => [C + r * Math.cos(a * Math.PI / 180), C + r * Math.sin(a * Math.PI / 180)];
    const arc = (a0, a1) => { const [x0, y0] = pt(a0), [x1, y1] = pt(a1); return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${R} ${R} 0 0 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`; };
    const A0 = 180, A1 = 270, [nx, ny] = pt(o.numAngle ?? 225, 205);
    return `<div class="rankarc" style="left:${x - 24}px;bottom:${b - 24}px">
      <svg viewBox="0 0 355 355" width="355" height="355">
        <path d="${arc(A0, A1)}" stroke="rgba(7,6,13,.55)" stroke-width="14" fill="none"/>
        <path d="${arc(A0, A1)}" stroke="rgba(243,240,255,.30)" stroke-width="10" fill="none"/>
        ${f > 0 ? `<path d="${arc(A0, A0 + (A1 - A0) * f)}" stroke="#22E4FF" stroke-width="10" fill="none"/>` : ""}
      </svg>
      <div class="rk" style="left:${nx.toFixed(0)}px;top:${ny.toFixed(0)}px"><div class="t-label c-2 shadow" style="font-size:17px">RANK</div><div class="t-status shadow" style="margin-top:4px">${o.rank ?? 6}</div></div>
    </div>`;
  };
  P.minimap = (o = {}) => `
    <div class="minimap" style="left:${o.x ?? 58}px;bottom:${o.b ?? 80}px;${o.style || ""}">
      <svg viewBox="0 0 300 300" width="297" height="297" style="display:block">
        <rect width="300" height="300" fill="#1b1932"/>
        <g stroke="#5a5680" stroke-width="22" fill="none"><path d="M-10 70 L320 240"/><path d="M190 -10 V320"/><path d="M90 320 L260 20"/><path d="M-10 222 H320" stroke-width="10"/></g>
        ${o.route !== false ? `<path d="M148 168 L206 40" stroke="#FF2D95" stroke-width="9" fill="none"/>` : ""}
        <g fill="#F3F0FF" stroke="#07060D" stroke-width="4"><circle cx="100" cy="92" r="9"/><circle cx="206" cy="124" r="9"/><circle cx="182" cy="226" r="9"/></g>
        <path d="M148 150 L164 186 L148 178 L132 186 Z" fill="#F3F0FF" transform="rotate(20 148 170)"/>
      </svg>
    </div>
    <div class="abs round" style="left:${(o.x ?? 58) + 136}px;bottom:${(o.b ?? 80) - 14}px;width:34px;height:34px;background:var(--ink);border:2px solid var(--hair-bot);display:flex;align-items:center;justify-content:center;font:italic 800 20px Barlow">N</div>
    ${o.label ? `<div class="abs t-label c-2 shadow" style="left:${o.x ?? 58}px;width:307px;text-align:center;bottom:${(o.b ?? 80) - 52}px">${o.label}</div>` : ""}`;

  /* speed gauge (image arcs in Roblox). */
  P.gauge = (speed, boost, o = {}) => {
    const R = 170, C = 201, arc = (r, a0, a1) => {
      const p = (a) => [C + r * Math.cos(a * Math.PI / 180), C + r * Math.sin(a * Math.PI / 180)];
      const [x0, y0] = p(a0), [x1, y1] = p(a1);
      return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`;
    };
    const A0 = 135, A1 = 405, f = Math.min(1, speed / 240), sEnd = A0 + (A1 - A0) * f, hot = A0 + (A1 - A0) * 0.8;
    let ticks = "";
    for (let i = 0; i <= 18; i++) { const a = (A0 + i * 15) * Math.PI / 180; ticks += `<path d="M${C + 190 * Math.cos(a)} ${C + 190 * Math.sin(a)} L${C + 200 * Math.cos(a)} ${C + 200 * Math.sin(a)}" stroke="rgba(243,240,255,.45)" stroke-width="3"/>`; }
    return `<div class="abs" style="right:${o.r ?? 40}px;bottom:${o.b ?? 28}px;width:403px;height:403px">
      <svg viewBox="0 0 403 403" width="403" height="403" style="position:absolute;inset:0">
        <circle cx="${C}" cy="${C}" r="186" fill="rgba(14,13,26,.72)"/>${ticks}
        <path d="${arc(R, A0, A1)}" stroke="rgba(243,240,255,.18)" stroke-width="12" fill="none"/>
        <path d="${arc(R, A0, Math.min(sEnd, hot))}" stroke="#F3F0FF" stroke-width="12" fill="none"/>
        ${sEnd > hot ? `<path d="${arc(R, hot, sEnd)}" stroke="#FF2D95" stroke-width="12" fill="none"/>` : ""}
        <path d="${arc(146, A0, A1)}" stroke="rgba(243,240,255,.12)" stroke-width="7" fill="none"/>
        <path d="${arc(146, A0, A0 + 270 * boost / 100 + 0.01)}" stroke="#22E4FF" stroke-width="7" fill="none"/>
      </svg>
      <div class="num abs" style="left:0;right:0;top:128px;text-align:center;font-size:150px">${speed}</div>
      <div class="t-label abs c-2" style="left:0;right:0;top:262px;text-align:center">MPH</div>
      <div class="t-label abs c-cyan" style="left:0;right:0;top:312px;text-align:center">BOOST ${boost}%</div>
    </div>`;
  };

  P.actionbar = (on) => `<div class="actionbar">` + ["car", "garage", "flag", "wrench", "sliders"].map((n, i) => `<div class="btn icon ${i === on ? "on" : ""}">${P.ic(n)}</div>`).join("") + `</div>`;
  P.rank = (o = {}) => `<div class="abs" style="left:${o.x ?? 384}px;bottom:${o.b ?? 330}px;width:150px"><div class="t-label c-2 shadow">DRIVER RANK</div><div class="t-status shadow" style="margin:8px 0 8px">${o.rank ?? 6}</div><div class="progress"><i style="width:${o.p ?? 22}%"></i></div></div>`;
  P.medal = (k) => `<i class="medal ${k}"></i>`;
  P.key = (k, wide) => `<span class="keycap ${wide ? "wide" : ""}">${k}</span>`;
  P.glyph = (k, bumper) => `<span class="glyph ${bumper ? "bumper" : ""}">${k}</span>`;
  P.modal = (title, body, btns, style = "", cls = "") => `<div class="modal ${cls}" style="${style}"><div class="mhead"><div class="titlemark"></div><div class="t-sect" style="font-size:46px">${title}</div></div><div class="mbody">${body}</div>${btns ? `<div class="mbtns">${btns.join("")}</div>` : ""}</div>`;
  P.toast = (text, kind = "", icon) => `<div class="toast ${kind}">${icon ? P.ic(icon) : ""}<span class="t-value" style="text-transform:none;font-style:normal;font-weight:600;font-family:Barlow">${text}</span></div>`;
  P.prompt = (action, obj, cap, cls = "") => `<div class="prompt ${cls}"><span class="${/main/.test(cls) ? "t-btnmain" : "t-btn"}">${action}</span>${obj ? `<span class="obj t-label c-2">${obj}</span>` : ""}${cap || ""}</div>`;
  P.caption = (t, x, y, w) => `<div class="abs note" style="left:${x}px;top:${y}px;${w ? `width:${w}px` : ""}"><span class="sheetlabel">${t.split("|")[0]}</span>${t.split("|")[1] ? "<br>" + t.split("|")[1] : ""}</div>`;
  window.P = P;
})();
