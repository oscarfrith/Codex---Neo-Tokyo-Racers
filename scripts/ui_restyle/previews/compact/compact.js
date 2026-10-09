/* Pulse preview helpers, Compact class (phones, landscape). Uses ../shared/pulse.js (P) for the
   shared component markup and adds the phone page shell, guides and phone-only compositions.
   Device size = window size. Scale = clamp(height / 390, 0.85, 1.10), applied with CSS zoom to the
   .cx stage, which is laid out in Compact design units inside the device safe area. */
(function () {
  const C = {};
  const ic = P.ic;

  C.metrics = () => {
    const q = new URLSearchParams(location.search);
    const w = +q.get("w") || window.innerWidth, h = +q.get("h") || window.innerHeight;   // ?w=568&h=320 pins the device size
    const notch = w / h > 2.0;                       // 19.5:9 phones have a notch and a home bar
    const L = notch ? (h >= 420 ? 59 : 47) : 0, R = L, B = notch ? 21 : 0;
    const s = Math.max(0.85, Math.min(1.10, h / 390));
    return { w, h, L, R, B, s, W: (w - L - R) / s, H: (h - B) / s, t: Math.max(48, 48 / s), g: Math.max(8, 8 / s), tbw: 120 / s, tbh: 52 / s };
  };

  /* o: {scene, scrim:"hud"|"garage"|"menu"|"", dim, under:html, over:"modal", foot:bool, title} */
  C.page = (o, html) => {
    const m = C.metrics();
    const vars = `--t:${m.t.toFixed(2)}px;--g:${m.g.toFixed(2)}px;--tbw:${m.tbw.toFixed(2)}px;--tbh:${m.tbh.toFixed(2)}px`;
    const stage = (inner) => `<div class="safe" style="left:${m.L}px;width:${m.w - m.L - m.R}px;height:${m.h - m.B}px"><div class="cx" style="zoom:${m.s};width:${m.W.toFixed(2)}px;height:${m.H.toFixed(2)}px;${vars}">${inner}</div></div>`;
    const guides = `<div class="guide-safe">` +
      (m.L ? `<div class="edge" style="left:0;top:0;bottom:0;width:${m.L}px"></div><div class="edge" style="right:0;top:0;bottom:0;width:${m.R}px"></div><div class="edge" style="left:${m.L}px;right:${m.R}px;bottom:0;height:${m.B}px"></div>` +
        `<div class="line" style="left:${m.L}px;top:0;bottom:0;border-left-width:1px"></div><div class="line" style="right:${m.R}px;top:0;bottom:0;border-left-width:1px"></div><div class="line" style="left:${m.L}px;right:${m.R}px;bottom:${m.B}px;border-top-width:1px"></div>` +
        `<div class="bezel"></div><div class="notch"></div><div class="home"></div>` +
        `<div class="tag" style="left:${m.L + 4}px;bottom:${m.B + 3}px">safe area ${m.L} / ${m.R} / ${m.B} &middot; ${m.w}x${m.h} &middot; scale ${m.s.toFixed(2)}</div>`
        : `<div class="tag" style="left:4px;bottom:3px">no insets &middot; ${m.w}x${m.h} &middot; scale ${m.s.toFixed(2)}</div>`) +
      `</div><div class="guide-top" style="left:${m.L + 8}px"><i></i><i></i><b>Roblox top bar</b></div>` +
      (o.foot ? `<div class="guide-rbx" style="left:${m.L + 22}px;bottom:${m.B + 16}px;width:112px;height:112px"><div class="guide-rbx inner" style="position:static;width:48px;height:48px"></div></div>` +
        `<div class="guide-rbx" style="left:${m.L + 30}px;bottom:${m.B + 132}px;width:96px;height:14px;border:0;background:none">Roblox thumbstick</div>` +
        `<div class="guide-rbx" style="right:${m.R + 26}px;bottom:${m.B + 26}px;width:72px;height:72px">Roblox<br>jump</div>` : "");
    const scrim = o.scrim ? `<div class="scrim-${o.scrim}"></div>` : "";
    document.body.innerHTML = `<div class="device" style="width:${m.w}px;height:${m.h}px">${o.bg ?? P.scene(o.scene || "city", "", o.dim)}${scrim}` +
      (o.under ? stage(o.under) + `<div class="scrim-modal"></div>` : "") + stage(html) + guides + `</div>`;
    document.title = o.title || document.title;
  };

  /* ---- pieces ------------------------------------------------------------ */
  C.title = (text, sub) => `<div class="c-title"><div class="titlemark"></div><div class="t-title shadow">${text}</div>${sub ? `<div class="sub t-label c-2 shadow">${sub}</div>` : ""}</div>`;
  /* status strip. o: {garage, tier, rating, rank, cash, plus, foot} */
  C.statusInner = (o = {}) => {
    const first = o.garage
      ? `<div class="seg">${ic("garage")}<span class="t-status">${o.garage}</span>${o.plus ? `<span class="plus">${ic("plus")}</span>` : ""}</div>`
      : o.tier ? `<div class="seg">${ic("car")}<span class="tier">${o.tier}</span><span class="t-status">${o.rating}</span></div>`
      : `<div class="seg">${ic("person")}<span class="t-status">ON FOOT</span></div>`;
    return first + `<div class="seg"><span class="rankring">${o.rank ?? 6}</span></div>` +
      `<div class="cash fixed">${ic("coin")}<span class="t-status">${o.cash || "$3.61M"}</span>${o.plus ? `<span class="plus" style="background:rgba(7,6,13,.16);margin-left:3px">${ic("plus")}</span>` : ""}</div>`;
  };
  C.status = (o = {}) => `<div class="status">${C.statusInner(o)}</div>`;
  C.actions = (rows, w = 212) => `<div class="c-actions" style="width:${w}px">` + rows.map((r) => `<div class="r">${r.join("")}</div>`).join("") + `</div>`;
  C.btn = (label, icon, variant = "") => P.btn(label, icon, variant);
  C.ibtn = (icon, cls = "") => `<div class="btn icon ${cls}">${ic(icon)}</div>`;

  C.segbar = (v, gain = 0, n = 12) => {
    const base = Math.round(Math.min(v, v + gain) / 100 * n), g = Math.max(gain ? 1 : 0, Math.round(Math.max(v, v + gain) / 100 * n) - base);
    return `<div class="segbar" style="width:${n * 7 - 2}px"><i style="width:${base * 7}px"></i>${gain ? `<i class="${gain > 0 ? "gain" : "loss"}" style="width:${Math.min(g, n - base) * 7 - (base + g >= n ? 2 : 0)}px"></i>` : ""}</div>`;
  };
  /* stat panel. o: {name, badge, sub, stats:[[label,value,gain]], style} */
  C.statpanel = (o) => {
    const anyGain = o.stats.some((s) => s[2]);
    let h = `<div class="statpanel panel" style="${o.style || ""}"><div class="head"><div class="t-status" style="font-size:var(--fs-sect);font-weight:900">${o.name}</div>${o.badge ? `<span class="tierrating">${o.badge}</span>` : ""}</div>`;
    if (o.sub) h += `<div class="subline"><span class="t-label c-2">${o.sub}</span></div>`;
    h += `<div style="height:6px"></div>`;
    o.stats.forEach((s) => {
      const gain = s[2] || 0;
      h += `<div class="stat"><span class="lab t-label">${s[0]}</span>${C.segbar(s[1] - Math.max(gain, 0), gain, anyGain ? 9 : 12)}` +
        `<span class="val t-value ${gain > 0 ? "c-cyan" : gain < 0 ? "c-pink" : ""}">${s[1]}</span>` +
        (anyGain ? (gain ? `<span class="chip gain ${gain > 0 ? "cyan" : "pink"}">${gain > 0 ? "+" : ""}${gain}</span>` : `<span style="width:26px;flex:none"></span>`) : "") + `</div>`;
    });
    return h + `</div>`;
  };
  C.modal = (title, body, btns, style = "", extra = "") => `<div class="modal" style="${style}"><div class="mhead"><div class="titlemark"></div><div class="t-sect">${title}</div>${extra}</div><div class="mbody">${body}</div>${btns ? `<div class="mbtns">${btns.join("")}</div>` : ""}</div>`;
  /* modal slot: the block is centred in the area to the right of the Roblox top bar */
  C.modalSlot = (inner) => `<div class="abs" style="left:var(--tbw);right:var(--m);top:var(--m);bottom:var(--m);display:flex;align-items:center;justify-content:center">${inner}</div>`;

  C.minimap = () => `
    <div class="minimap"><svg viewBox="0 0 300 300" width="98" height="98" style="display:block">
      <rect width="300" height="300" fill="#1b1932"/>
      <g stroke="#5a5680" stroke-width="22" fill="none"><path d="M-10 70 L320 240"/><path d="M190 -10 V320"/><path d="M90 320 L260 20"/><path d="M-10 222 H320" stroke-width="10"/></g>
      <path d="M148 168 L206 40" stroke="#FF2D95" stroke-width="10" fill="none"/>
      <g fill="#F3F0FF" stroke="#07060D" stroke-width="5"><circle cx="100" cy="92" r="11"/><circle cx="206" cy="124" r="11"/><circle cx="182" cy="226" r="11"/></g>
      <path d="M148 142 L170 192 L148 180 L126 192 Z" fill="#F3F0FF" transform="rotate(20 148 170)"/></svg></div>
    <div class="c-north">N</div>`;

  C.gauge = (speed, boost) => {
    const c = 62, arc = (r, a0, a1) => {
      const p = (a) => [c + r * Math.cos(a * Math.PI / 180), c + r * Math.sin(a * Math.PI / 180)];
      const [x0, y0] = p(a0), [x1, y1] = p(a1);
      return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`;
    };
    const A0 = 135, A1 = 405, f = Math.min(1, speed / 240), sEnd = A0 + 270 * f + 0.01, hot = A0 + 270 * 0.8;
    let ticks = "";
    for (let i = 0; i <= 18; i++) { const a = (A0 + i * 15) * Math.PI / 180; ticks += `<path d="M${c + 58.5 * Math.cos(a)} ${c + 58.5 * Math.sin(a)} L${c + 61.5 * Math.cos(a)} ${c + 61.5 * Math.sin(a)}" stroke="rgba(243,240,255,.45)" stroke-width="1.2"/>`; }
    return `<div class="c-gauge"><svg viewBox="0 0 124 124" width="124" height="124" class="fill" style="filter:drop-shadow(0 0 4px rgba(34,228,255,.35))">
        <circle cx="${c}" cy="${c}" r="57" fill="rgba(14,13,26,.74)"/>${ticks}
        <path d="${arc(52, A0, A1)}" stroke="rgba(243,240,255,.18)" stroke-width="5" fill="none"/>
        <path d="${arc(52, A0, Math.min(sEnd, hot))}" stroke="#F3F0FF" stroke-width="5" fill="none"/>
        ${sEnd > hot ? `<path d="${arc(52, hot, sEnd)}" stroke="#FF2D95" stroke-width="5" fill="none"/>` : ""}
        <path d="${arc(44, A0, A1)}" stroke="rgba(243,240,255,.12)" stroke-width="3" fill="none"/>
        <path d="${arc(44, A0, A0 + 270 * boost / 100 + 0.01)}" stroke="#22E4FF" stroke-width="3" fill="none"/></svg>
      <div class="num abs" style="left:0;right:4px;top:39px;text-align:center;font-size:var(--fs-speed)">${speed}</div>
      <div class="t-label abs c-2" style="left:0;right:0;top:84px;text-align:center">MPH</div></div>`;
  };

  /* touch drive controls. o: {boost:0..100, on:[names], off:bool} */
  C.touch = (o = {}) => {
    const on = (n) => (o.on || []).includes(n) ? " on" : "", off = o.off ? " off" : "";
    return `<div class="tc-left">
        <div class="tc boost${on("Boost")}${off}">${ic("bolt")}<span class="t-btn">BOOST</span><i class="lvl" style="width:${o.boost ?? 100}%"></i></div>
        <div class="tc drift${on("DriftLeft")}${off}" style="left:0">${ic("left")}<span class="t-label">DRIFT</span></div>
        <div class="tc drift${on("DriftRight")}${off}" style="right:0"><span class="t-label">DRIFT</span>${ic("right")}</div>
        <div class="tc turn${on("TurnLeft")}${off}" style="left:0">${ic("left")}</div>
        <div class="tc turn${on("TurnRight")}${off}" style="right:0">${ic("right")}</div></div>
      <div class="tc-right">
        <div class="tc brake${on("Brake")}${off}">${ic("down")}<span class="t-label">BRAKE</span></div>
        <div class="tc accel${on("Accelerator")}${off}">${ic("up")}<span class="t-label">ACCEL</span></div></div>`;
  };

  /* free-roam HUD. o: {mode:"foot"|"drive", open:index, speed, boost, on:[...], noExit} */
  C.hud = (o = {}) => {
    const drive = o.mode === "drive";
    return C.minimap() + `<div class="c-district t-label c-2 shadow">AKANE DISTRICT</div>` +
      P.actionbar(o.open) +
      `<div class="c-hudstatus"><div class="status static">${C.statusInner(drive ? { tier: "S", rating: 939, plus: 1 } : { plus: 1 })}</div><div class="c-cashhit hit"></div></div>` +
      (drive ? `<div class="c-rightcol">${o.noExit ? "" : `<div class="btn sec" style="padding:0 6px">${ic("exit")}<span>EXIT</span></div>`}</div>` + C.gauge(o.speed ?? 0, o.boost ?? 100) + C.touch({ boost: o.boost ?? 100, on: o.on }) : "");
  };

  /* garage shell. o: {title, tabs, status, stat, head, rail, actions, railRight} */
  C.garage = (o) => C.title(o.title) + P.tabs(o.tabs) + C.status(o.status || { garage: "3 / 4", plus: 1 }) +
    (o.stat ? C.statpanel(o.stat) : "") +
    `<div class="c-railhead">${o.head}</div>` +
    `<div class="c-rail" style="right:calc(var(--m) + 212px + var(--g))">${o.rail}</div>` + C.actions(o.actions);

  C.STATS = [["SPEED", 80], ["ACCEL", 74], ["HANDLING", 63], ["DRIFT", 61], ["BRAKING", 62], ["BOOST", 61]];
  window.C = C;
})();
