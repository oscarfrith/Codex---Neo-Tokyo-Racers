/* Shared compositions for the regular previews: free-roam HUD, garage frame, paint panel, race HUD parts. */
(function () {
  const P = window.P;
  const HEAD_TABS = [{ l: "PARTS", i: "wrench" }, { l: "UPGRADES", i: "upgrade" }, { l: "PAINT", i: "brush" }];
  P.customiseTabs = (on) => P.tabs(HEAD_TABS.map((t, i) => ({ ...t, on: i === on })));

  /* free-roam HUD. o:{onfoot, speed, boost, open (action index), tier, rating, district, noRow, dimmed, cash} */
  P.freeroam = (o = {}) => `
    ${P.scene("city")}<div class="scrim-hud"></div>
    ${P.status({ hud: 1, tier: o.onfoot ? null : (o.tier || "S"), rating: o.rating || 939, cash: o.cash || "$3,613,709", rank: 6 })}
    ${P.actionbar(o.open ?? -1)}
    ${o.sidePanel ? "" : P.minimap({ label: o.district || "AKANE DISTRICT", route: !!o.route }) + P.rankarc({ rank: 6, p: o.xp ?? 22 })}
    ${o.onfoot ? "" : P.gauge(o.speed ?? 0, o.boost ?? 100)}
    ${o.noRow ? "" : `<div class="btnrow centre" style="bottom:28px">${P.btn("CONTROLS", "gamepad", "sm")}${o.onfoot ? "" : P.btn("EXIT VEHICLE", "exit", "sm")}</div>`}
    ${o.dimmed ? `<div class="scrim-modal"></div>` : ""}`;

  /* paint panel (left column of the garage frame) */
  const SW = ["#FFFFFF", "#FF8A80", "#FFB980", "#FFE680", "#9CFF80", "#80FFD0", "#80E8FF", "#80A8FF", "#C080FF", "#3A3A44", "#8A1A1A", "#8A4A12", "#86801A", "#1E7A1E", "#167A5A", "#16707A", "#1A2470", "#4A1680"];
  P.paintPanel = (channels, on = 0, top = 196) => `
    <div class="panel abs" style="left:var(--margin);top:${top}px;width:480px">
      ${P.segswitch(channels.map((c, i) => ({ l: c, on: i === on })))}
      ${[["HUE", "236&deg;", 66, "linear-gradient(90deg,#f00,#ff0,#0f0,#0ff,#00f,#f0f,#f00)"], ["SATURATION", "52%", 52, "linear-gradient(90deg,#F3F0FF,#3040ff)"], ["BRIGHTNESS", "26%", 26, "linear-gradient(90deg,#000,#F3F0FF)"]].map((s) => `
        <div class="flex jb" style="margin:22px 0 12px"><span class="t-label">${s[0]}</span><span class="t-label c-2">${s[1]}</span></div>
        <div class="slider" style="background:${s[3]}"><b style="left:${s[2]}%"></b></div>`).join("")}
      <div style="display:grid;grid-template-columns:repeat(9,1fr);gap:4px;margin-top:26px">
        ${SW.map((c, i) => `<div style="height:36px;background:${c};${i === 16 ? "outline:3px solid var(--white);outline-offset:-1px" : ""}"></div>`).join("")}
      </div>
      <div class="flex ac g12" style="margin-top:16px"><div style="width:36px;height:36px;background:#1A2470;border:2px solid var(--hair-top)"></div><span class="t-label c-2">CURRENT</span></div>
    </div>`;

  /* dropdown (closed), in the Button family */
  P.dropdown = (label, value, w = 300) => `<div class="btn sm" style="width:${w}px;justify-content:space-between;padding:0 16px 0 20px"><span><span class="c-muted">${label}</span>&nbsp; ${value}</span>${P.ic("down")}</div>`;

  /* race HUD pieces */
  P.routeMap = (kind, label) => `
    <div class="panel flush abs" style="left:40px;bottom:80px;width:360px;height:236px;display:flex;align-items:center;justify-content:center">
      <div style="position:relative">${P.route(kind, "var(--white)", 300, 9, null)}
        <div class="abs round" style="left:98px;top:76px;width:22px;height:22px;background:var(--cyan);border:4px solid var(--ink)"></div></div>
    </div>
    <div class="abs t-label c-2 shadow" style="left:40px;width:360px;text-align:center;bottom:36px">${label}</div>`;
  P.pips = (n, done) => `<div class="pips">${Array.from({ length: n }, (_, i) => `<div class="pip ${i < done ? "on" : ""}"></div>`).join("")}</div>`;
  P.timer = (label, time, delta, deltaCls, n, done) => `
    <div class="abs col ac" style="left:50%;transform:translateX(-50%);top:44px;align-items:center">
      <div class="panel flush" style="border-top:0;border-bottom:4px solid var(--pink);padding:10px 34px 12px;text-align:center">
        <div class="t-label c-2" style="margin-bottom:8px">${label}</div>
        <div class="num" style="font-size:84px;width:340px">${time}</div>
      </div>
      ${delta ? `<div class="chip ${deltaCls} lg" style="margin-top:8px">${delta}</div>` : ""}
      ${n ? `<div style="margin-top:12px">${P.pips(n, done)}</div>` : ""}
    </div>`;
  P.raceButtons = () => `<div class="btnrow centre" style="bottom:28px">${P.btn("RESET", "undo", "sm")}${P.btn("EXIT", "exit", "sm")}</div>`;

  /* event card (race start). o:{name, sub, route, you, entry, entryLabel, prize, prizeLabel, x, y} */
  P.eventCard = (o) => `
    <div class="abs" style="left:${o.x ?? 40}px;top:${o.y ?? 58}px;width:500px">
      <div class="panel" style="border-bottom:0;padding:22px 24px 20px">
        <div class="t-tile" style="font-size:44px">${o.name}</div>
        <div class="t-label c-2" style="margin-top:10px">${o.sub}</div>
        <div class="abs" style="right:0;top:-18px;width:76px;height:60px;transform:skewX(-10deg);background:repeating-conic-gradient(var(--white) 0 25%,var(--ink) 0 50%) 0 0/20px 20px"></div>
      </div>
      <div style="background:rgba(26,24,50,.92);height:200px;display:flex;align-items:center;justify-content:center">${P.route(o.route || "loop", "var(--cyan)", 270, 10, "var(--pink)")}</div>
      <div class="flex" style="height:112px;background:var(--slate)">
        <div style="width:250px;background:var(--white);color:var(--ink);padding:18px 24px;clip-path:polygon(0 0,100% 0,90% 100%,0 100%)"><div class="t-label">YOU</div><div class="t-tile" style="font-size:44px;margin-top:8px">${o.you}</div></div>
        <div style="padding:18px 12px"><div class="t-label c-2">${o.entryLabel || "ENTRY"}</div><div class="t-tile" style="font-size:44px;margin-top:8px">${o.entry}</div></div>
      </div>
      <div class="flex ac jb" style="height:68px;background:var(--slate);border-top:2px solid var(--hair-bot);padding-left:24px">
        <span class="t-value">${o.prizeLabel || "PRIZE"}</span>
        <div class="t-status c-ink" style="background:var(--yellow);height:68px;display:flex;align-items:center;padding:0 24px 0 34px;clip-path:polygon(16% 0,100% 0,100% 100%,0 100%)">${o.prize}</div>
      </div>
    </div>`;
})();
