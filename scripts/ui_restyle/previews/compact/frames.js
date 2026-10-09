/* Compact (phone) frames c01..c19, review 1 rework (2026-10-09). Each F.<id>() draws one frame at
   the window size. Positions use the stage variables (--m margin, --t touch target, --g gap,
   --bh visible button height, --hx hit extension, --tbw/--tbh top-bar reserve) and edge anchors,
   so one description holds from 568x320 to 932x430. */
(function () {
  const F = {}, ic = P.ic, btn = C.btn;
  const lab = (t, c = "c-2") => `<div class="t-label ${c}">${t}</div>`;
  const BAND = "calc(var(--m) + var(--bh) + var(--hx) + var(--g))";   /* content bottom above a bottom button row */
  const TOP2 = "calc(var(--tbh) + var(--t) - 4px)";                    /* content top under the tab row */
  const ROWY = "calc(var(--tbh) - 6px + var(--hx))";                   /* a 36-high control centred in the tab row */

  /* ---- c01 / c02 free roam -------------------------------------------------- */
  F.c01 = () => C.page({ scene: "city", scrim: "hud", foot: 1 }, C.hud({ mode: "foot" }));
  F.c02 = () => C.page({ scene: "city", scrim: "hud" }, C.hud({ mode: "drive", speed: 142, boost: 64 }));

  /* ---- c03 vehicles list (side panel) --------------------------------------- */
  const cars = [["S", "SERAPH", 1], ["D", "STINGER"], ["D", "ZEPHYR"], ["C", "AURORA"], ["B", "ENDURA"], ["A", "ROSSO"], ["E", "PIERCER MK1"]];
  F.c03 = () => C.page({ scene: "city", scrim: "hud", foot: 1 }, C.hud({ mode: "foot", open: 0, panel: 1 }) + `
    <div class="c-side">
      <div class="flex" style="gap:var(--g)">
        <div class="btn dd">${lab("CLASS")}<span>ALL</span>${ic("down")}</div>
        <div class="btn dd">${lab("SORT")}<span>TIER</span>${ic("down")}</div>${C.ibtn("close")}
      </div>
      <div class="grid">
        <div class="ct"><div class="vis">${ic("plus")}</div><div class="nm">BUY MORE</div></div>` +
        cars.map((c) => C.tile({ cls: "car", tier: c[0], name: c[1], vis: P.sil("car"), sel: c[2] })).join("") + `
      </div>
      <div class="btn danger block">DESPAWN SERAPH</div>
    </div>`);

  /* ---- c04 modals ----------------------------------------------------------- */
  const seg = (opts, on) => `<div class="segswitch">` + opts.map((o, i) => `<div class="opt t-label ${i === on ? "on" : ""}" style="font-weight:800">${o}</div>`).join("") + `</div>`;
  const setrow = (l, opts, on) => `<div class="setrow"><div class="lab t-label c-2">${l}</div>${seg(opts, on)}</div>`;
  F.c04a = () => C.page({ scene: "city", scrim: "hud", under: C.hud({ mode: "foot", open: 4 }) },
    C.modalSlot(C.modal("SETTINGS",
      setrow("TOUCH CONTROLS", ["ARROWS", "THUMBSTICK", "TILT"], 0) + setrow("MINIMAP", ["ROTATING", "NORTH UP"], 0) + setrow("PASSENGERS", ["FRIENDS", "ANYONE", "NOBODY"], 0),
      [btn("DONE", "tick", "main nochev")], "width:400px")));
  const pack = (cash, robux, best) => `<div style="position:relative;flex:1;height:58px;opacity:.6;background:rgba(243,240,255,.10)">${best ? `<div class="chip white abs" style="right:0;top:0">BEST</div>` : ""}
      <div class="abs t-btnmain c-yellow" style="left:6px;bottom:24px;font-weight:900">${cash}</div><div class="abs t-label c-2" style="left:6px;bottom:6px">${robux}</div></div>`;
  F.c04b = () => C.page({ scene: "city", scrim: "hud", under: C.hud({ mode: "foot" }) },
    C.modalSlot(C.modal("GET CASH",
      `<div class="flex" style="gap:var(--g)">${pack("$10,000", "49 ROBUX")}${pack("$30,000", "99 ROBUX")}${pack("$75,000", "199 ROBUX")}${pack("$200,000", "399 ROBUX", 1)}</div>
       <div class="t-body" style="margin-top:6px">${ic("lock")} Cash packs are not available yet. Earn Cash by driving, racing and jobs.</div>`,
      [btn("CLOSE", "close")], "width:404px",
      `<div class="flex ac" style="margin-left:auto;gap:6px">${lab("BALANCE")}<div class="c-cash" style="height:22px">${ic("coin")}<span>$3,613,709</span></div></div>`)));

  /* ---- c05 / c06 race menu -------------------------------------------------- */
  const evrow = (kind, small, name, modes, laps, players, prize, dis) => `
    <div class="row ev${dis ? " dis" : ""}">
      <div class="rt">${P.route(kind, "var(--white)", 58, 15, null)}</div>
      <div class="grow t-tile">${name}</div>
      <div class="t-label c-2" style="width:190px">${small} &middot; ${modes}</div>
      <div class="flex ac t-label" style="gap:4px;width:84px">${ic("laps")}${laps}<span style="width:5px"></span>${ic("players")}${players}</div>
      <div class="chip yellow lg" style="min-width:62px;justify-content:center">${prize}</div>${ic("right", "c-2")}
    </div>`;
  const raceStrip = () => C.strip({ car: { tier: "S", pi: 939, fixed: 1 } });
  F.c05 = () => C.page({ scene: "city", scrim: "menu" },
    C.title("") + C.tabs([{ l: "ALL EVENTS", on: 1 }, { l: "TIME TRIALS" }, { l: "RACES" }], "left:calc(var(--tbw) + 16px);top:calc((var(--tbh) - var(--t)) / 2)") + raceStrip() + `
     <div class="abs col" style="left:var(--m);right:var(--m);top:var(--tbh);bottom:${BAND};gap:4px;overflow:hidden">` +
      evrow("loop", "CIRCUIT", "SHOWROOM LOOP", "TIME TRIAL &middot; RACE", "3", "2 TO 6", "$10,000") +
      evrow("sprint", "SPRINT", "WATERFRONT SPRINT", "TIME TRIAL &middot; RACE", "1", "2 TO 6", "$8,000") +
      evrow("canal", "CIRCUIT", "SHIFTED CANAL SPRINT", "RACE", "3", "2 TO 8", "$20,000") +
      evrow("sprint", "SPRINT", "HARBOUR RUN", "TIME TRIAL", "1", "1", "$6,000") +
      evrow("loop", "CIRCUIT", "AKANE RING", "RACE", "5", "2 TO 8", "$30,000") + `</div>
     <div class="abs t-label c-2" style="left:var(--m);bottom:var(--m);height:var(--bh);display:flex;align-items:center">5 EVENTS</div>` +
    C.actions([btn("EXIT", "exit")], "low"));

  F.c06 = () => C.page({ scene: "city", scrim: "menu" },
    C.title("SHOWROOM LOOP") + raceStrip() + `
    <div class="abs col" style="left:var(--m);right:calc(var(--m) + 212px + var(--g));top:var(--tbh);bottom:${BAND};gap:var(--g)">
      <div style="position:relative;height:50px;flex:none;background:url(../shared/bg/city.jpg) center 62%/cover;border-bottom:2px solid var(--pink)">
        <div class="fill" style="background:linear-gradient(0deg,rgba(7,6,13,.8),rgba(7,6,13,.15))"></div>
        <div class="abs t-label" style="left:8px;top:6px">EVENT 1 OF 2</div>
        <div class="abs t-tab shadow" style="left:8px;bottom:6px">CIRCUIT &middot; TIME TRIAL &middot; RACE</div>
      </div>
      <div class="panel" style="flex:1;display:flex;align-items:center;justify-content:center;min-height:0">${P.route("loop", "var(--white)", 230, 8)}</div>
    </div>
    <div class="panel abs" style="right:var(--m);top:var(--tbh);width:212px;padding:1px 8px">` +
      P.fact("route", "ROUTE", "CIRCUIT") + P.fact("laps", "LAPS", "3") + P.fact("checkpoint", "CHECKPOINTS", "17") + P.fact("players", "PLAYERS", "2 TO 6") +
      `<div class="fact"><span class="t-label c-2">PRIZE</span><span class="v chip yellow lg">$10,000</span></div></div>` +
    C.actions([btn("BACK", "back"), btn("SET ROUTE", "route"), btn("TELEPORT", "pin", "main")], "low"));

  /* ---- c07 race entry ------------------------------------------------------- */
  const medalrow = (k, name, time, yours) => `<div class="row ${yours ? "you" : "bare"}" style="min-height:22px;height:22px;border-bottom:0;padding:0 6px;gap:6px">${P.medal(k)}<span class="t-label" style="font-weight:800">${name}</span>${yours ? `<span class="t-label c-pink">YOURS</span>` : ""}<span class="right t-value">${time}</span></div>`;
  F.c07 = () => C.page({ scene: "city", scrim: "menu" },
    C.title("SHOWROOM LOOP") + C.tabs([{ l: "TIME TRIAL", on: 1 }, { l: "RACE" }]) + raceStrip() + `
    <div class="abs flex" style="right:var(--m);top:${ROWY};gap:calc(var(--hx) * 2 + var(--g))">` +
      [["E", "done"], ["D", "done"], ["C", "on"], ["B", ""], ["A", "locked"], ["S", "locked"]].map((t) => `<div class="tierbtn ${t[1]}">${t[0]}</div>`).join("") + `</div>
    <div class="panel abs col" style="left:var(--m);right:calc(var(--m) + 196px + var(--g) + 196px + var(--g));top:${TOP2};bottom:${BAND}">
      ${lab("3 LAPS &middot; 17 CP")}
      <div style="flex:1;display:flex;align-items:center;justify-content:center;min-height:0;overflow:hidden">${P.route("loop", "var(--cyan)", 170, 10)}</div>
      <div class="flex ac" style="gap:var(--g);margin-bottom:var(--hx)">${C.ibtn("minus")}<div class="t-sect" style="flex:1;text-align:center">3 LAPS</div>${C.ibtn("plus")}</div>
    </div>
    <div class="abs col" style="right:calc(var(--m) + 196px + var(--g));width:196px;top:${TOP2};bottom:${BAND};gap:var(--g)">
      <div class="panel" style="padding:7px 8px">${lab("YOUR BEST &middot; STINGER")}<div class="num" style="font-size:var(--fs-timer);margin-top:6px">01:03.275</div></div>
      <div class="panel" style="flex:1;padding:4px 2px;display:flex;flex-direction:column;justify-content:space-around">` +
        medalrow("plat", "PLATINUM", "00:58.000") + medalrow("", "GOLD", "01:02.000", 1) + medalrow("silver", "SILVER", "01:08.000") + medalrow("bronze", "BRONZE", "01:15.000") + `</div>
    </div>
    <div class="panel abs" style="right:var(--m);width:196px;top:${TOP2};bottom:${BAND};padding:7px 8px">
      ${lab("TIER C &middot; PLATINUM PRIZE")}
      <div class="chip yellow" style="height:24px;font-size:var(--fs-sect);font-weight:900;margin-top:6px;padding:0 7px 0 6px">$25,000</div>
      <div class="t-label c-2" style="margin-top:8px">DAILY BONUS READY</div>
      <div class="num abs" style="right:8px;bottom:8px;font-size:var(--fs-pos)">C</div>
    </div>` +
    C.actions([btn("EXIT", "exit"), btn("RECORDS", "trophy"), btn("CHOOSE VEHICLE", "car", "main")], "low"));

  /* ---- c08 / c09 race ------------------------------------------------------- */
  const boardrow = (p, name, gap, you) => `<div class="row ${you ? "you" : ""}"><span class="p t-label" style="font-weight:800">${p}</span><span class="t-label" style="font-weight:800">${name}</span><span class="right t-label c-2">${gap}</span></div>`;
  const board = () => `<div class="c-board">${boardrow(1, "NEONRIDER", "&minus;1.8")}${boardrow(2, "YOU", "", 1)}${boardrow(3, "CYBERWAVE", "+0.6")}</div>`;
  const sessionBtns = () => `<div class="abs flex" style="right:calc(var(--m) + var(--hx));top:calc(var(--m) + 64px + var(--g) + var(--hx));gap:calc(var(--hx) * 2 + var(--g))">${C.ibtn("undo")}${C.ibtn("exit")}</div>`;
  F.c08 = () => C.page({ scene: "race", scrim: "hud" }, `
    <div class="c-leftzone">
      <div class="flex" style="align-items:flex-start;gap:2px"><span class="num shadow" style="font-size:var(--fs-pos)">2</span><span class="t-sect shadow">ND</span><span class="t-label c-2 shadow" style="align-self:flex-end;margin-left:2px">/ 8</span></div>
      <div class="chip ink" style="margin-top:6px;border-left:2px solid var(--cyan)">LAP 2 / 3</div>
    </div>
    <div class="c-timer"><div class="box"><div class="num" style="font-size:var(--fs-timer)">01:03.275</div></div>
      <div class="chip cyan">LAP &minus;0.412</div>
      <div class="pips">${Array.from({ length: 12 }, (_, i) => `<i class="pip ${i < 7 ? "on" : ""}"></i>`).join("")}</div></div>` +
    board() + sessionBtns() + C.speed(187, 30) + C.touch({ on: ["Accelerator", "TurnRight"] }));

  F.c09 = () => C.page({ scene: "race", scrim: "hud", dim: 0.25 }, `
    <div class="abs col" data-x style="left:0;right:0;top:var(--tbh);align-items:center">
      <div class="t-sect shadow">GET READY</div>
      <div class="num" style="font-size:var(--fs-count);margin-top:8px;text-shadow:0 3px 0 rgba(7,6,13,.55)">3</div>
      <div style="width:96px;height:2px;background:var(--pink);margin-top:8px"></div>
      <div class="t-label c-2 shadow" style="margin-top:6px">SHOWROOM LOOP &middot; RACE &middot; 3 LAPS</div>
    </div>
    <div class="c-leftzone"><div class="chip ink" style="border-left:2px solid var(--cyan)">GRID 2 / 8</div></div>` +
    board() + C.speed(0, 100) + C.touch({ off: 1 }));

  /* ---- c10 results ---------------------------------------------------------- */
  const hero = (l, v, c) => `<div>${`<div class="t-label shadow">${l}</div>`}<div class="num ${c}" style="font-size:var(--fs-hero);margin-top:6px;text-shadow:0 2px 0 rgba(7,6,13,.5)">${v}</div></div>`;
  const cell = (l, v) => `<div style="flex:1;padding:5px 8px">${lab(l)}<div class="t-value" style="margin-top:4px">${v}</div></div>`;
  const resrow = (p, name, time, you) => `<div class="row ${you ? "you" : "bare"}" style="min-height:22px;height:22px;padding:0 8px 0 0;gap:6px;border-bottom:0"><span class="t-label" style="font-weight:800;width:20px;text-align:center">${p}</span><span class="t-label" style="font-weight:800">${name}</span><span class="right t-label ${you ? "" : "c-2"}">${time}</span></div>`;
  F.c10 = () => C.page({ scene: "race", scrim: "menu" },
    C.title("RACE COMPLETE") + `
    <div class="abs t-label c-2" style="left:var(--m);top:calc(var(--tbh) + 2px)">SHIFTED CANAL SPRINT &middot; 3 LAPS &middot; SERAPH</div>
    <div class="abs col" style="left:var(--m);top:calc(var(--tbh) + 30px);gap:14px">
      <div class="flex" style="gap:28px">${hero("BANKED", "$20,000", "c-yellow")}${hero("DRIVER XP", "+120", "c-pink")}</div>
      <div class="panel flush flex" style="width:330px">${cell("FINISH", "2ND OF 8")}${cell("TIME", "03:11.842")}${cell("BEST LAP", "01:02.966")}</div>
    </div>
    <div class="panel abs" style="right:var(--m);top:var(--m);width:208px;padding:6px 2px 4px">
      <div class="t-label c-2" style="padding:0 8px 4px">RESULTS</div>` +
      resrow(1, "NEONRIDER", "03:10.021") + resrow(2, "YOU", "03:11.842", 1) + resrow(3, "CYBERWAVE", "+0.612") + resrow(4, "NIGHTDRIFT", "+2.318") + resrow(5, "AKIRA_77", "+4.901") + resrow(6, "VOLTLINE", "+7.440") + resrow(7, "KOSMO", "+9.027") + resrow(8, "DRIFTCAT", "DNF") + `
    </div>` +
    C.actions([btn("RACE AGAIN", "loop"), btn("CONTINUE", "", "main")], "low"));

  /* ---- c11..c15 garage ------------------------------------------------------ */
  const gtabs = (on) => [{ l: "PARTS", i: "wrench", on: on === 0 }, { l: "UPGRADES", i: "upgrade", on: on === 1 }, { l: "PAINT", i: "brush", on: on === 2 }];
  const head = (h, extra = "") => `<div class="t-sect shadow">${h}</div>${extra}`;
  const sw = (a, b) => `<div class="flex" style="gap:var(--g);margin-left:4px"><div class="c-tab on shadow">${a}</div><div class="c-tab shadow">${b}</div></div>`;
  const dealer = () => C.garage({
    title: "DEALERSHIP", tabs: [{ l: "ALL" }, { l: "EXOTIC", on: 1 }, { l: "PIERCER" }, { l: "MUSCLE" }],
    strip: { car: { name: "ZEPHYR", tier: "D", pi: 390 }, garage: "0 / 2", cash: "$1.00M" },
    head: head("EXOTIC 2/6", sw("FOR SALE", "OWNED")),
    rail: [["E", "STINGER", 0, "OWNED"], ["D", "ZEPHYR", "$150K"], ["C", "AURORA", "$440K"], ["B", "ENDURA", "$1.40M", 0, 1], ["A", "ROSSO", "$4.40M", 0, 1], ["S", "SERAPH", "$9.80M", 0, 1], ["S", "HALO", "$12.0M", 0, 1]]
      .map((c, i) => C.tile({ cls: "car", tier: c[0], name: c[1], price: c[2] || null, unaff: c[4], corner: c[3] || null, vis: P.sil("car"), sel: i === 1 })).join(""),
    actions: [btn("EXIT", "exit"), btn("BUY $150,000", "", "buy")],
  });
  F.c11 = () => C.page({ scene: "dealer", scrim: "garage" }, dealer());

  const slots = [["FRONT BODY", "nose"], ["REAR BODY", ""], ["FRONT ENGINE", "eng"], ["REAR ENGINE", "eng"], ["DRIFT THRUSTERS", ""], ["OVERDRIVE", ""], ["WING", "wing"]];
  F.c12 = () => C.page({ scene: "garage", scrim: "garage" }, C.garage({
    title: "CUSTOMISE", tabs: gtabs(0),
    strip: { car: { name: "STINGER", tier: "D", pi: 316 }, garage: "3 / 4" },
    head: head("PARTS 3/7", `<div class="t-label c-2 shadow">FRONT ENGINE &middot; STANDARD &middot; FITTED</div>`),
    rail: slots.map((s, i) => C.tile({ name: s[0], vis: P.sil(s[1]), sel: i === 2, tick: 1 })).join(""),
    actions: [btn("BACK", "back"), btn("DRIVE", "wheel", "main")],
  }));

  F.c13 = () => C.page({ scene: "garage", scrim: "garage" }, C.garage({
    title: "CUSTOMISE", tabs: gtabs(0),
    strip: { car: { name: "STINGER", tier: "D", pi: 318, open: 1 }, garage: "3 / 4" },
    stats: C.stats("PREVIEW &middot; SPINE WING EVO", [["SPEED", 80], ["ACCEL", 74], ["HANDLING", 66, 3], ["DRIFT", 63, 2], ["BRAKING", 62], ["BOOST", 61]]),
    head: head("WING 3/9", sw("SHOP", "OWNED")),
    rail: [["SPINE STD", 0, 0, 1], ["SPINE GT", "$3,000"], ["SPINE EVO", "$6,000", "OWNED"], ["BRIDGE STD", "$42,000", 0, 0, 1], ["BRIDGE GT", "$84,000", 0, 0, 1], ["BRIDGE EVO", "$120K", 0, 0, 1], ["DUCKTAIL STD", "$18,000"]]
      .map((c, i) => C.tile({ name: c[0], price: c[2] ? null : c[1] || null, corner: c[2] || null, tick: c[3], vis: P.sil("wing"), sel: i === 2, locked: c[4], unaff: c[4] })).join(""),
    actions: [btn("BACK", "back"), btn("DRIVE", "wheel"), btn("EQUIP", "tick", "main")],
  }));

  const slider = (l, v, cls, pos) => `<div class="c-sl hit"><div class="flex jb">${lab(l)}<span class="t-label">${v}</span></div><div class="slider ${cls}"><b style="left:${pos}%"></b></div></div>`;
  const SW = ["#F3F0FF", "#232A6B", "#FF8A80", "#FFD180", "#B9F6CA", "#80D8FF", "#B388FF", "#3A3A44", "#8A1A1A", "#8A4A12", "#1E7A1E", "#16707A"];
  F.c14 = () => C.page({ scene: "garage", scrim: "garage" },
    C.title("CUSTOMISE") + C.tabs(gtabs(2)) + C.strip({ car: { name: "STINGER", tier: "D", pi: 316 }, garage: "3 / 4" }) + `
    <div class="abs flex ac" style="left:calc(var(--m) + 262px);top:calc(var(--tbh) - 6px);height:var(--t)">
      <div class="hit flex ac" style="width:var(--t);height:var(--t);justify-content:center">${ic("left", "t-tab")}</div>
      <div class="t-tab shadow" style="min-width:122px;text-align:center">WHOLE CAR <span class="c-2">1/10</span></div>
      <div class="hit flex ac" style="width:var(--t);height:var(--t);justify-content:center">${ic("right", "t-tab")}</div>
    </div>
    <div class="c-sliders" style="right:calc(var(--m) + 286px + var(--g))">${slider("HUE", "236&deg;", "hue", 66)}${slider("SATURATION", "52%", "sat", 52)}${slider("BRIGHTNESS", "26%", "bri", 26)}</div>` +
    `<div class="c-actions" style="bottom:calc(var(--m) + 40px + 4px + var(--hx) + var(--g))">${btn("BACK", "back")}${btn("DRIVE", "wheel")}${btn("APPLY", "tick", "main")}</div>
    <div class="c-swrail">${seg(["PRIMARY", "SECOND", "DETAIL", "NEON"], 0)}` +
      SW.map((c, i) => `<div class="swatch ${i === 1 ? "on" : ""}" style="background:${c}"></div>`).join("") + `</div>`);

  F.c15 = () => C.page({ scene: "dealer", scrim: "garage", under: dealer() },
    C.modalSlot(C.modal("BUY ZEPHYR?",
      `<div class="fact"><span class="t-label c-2">VEHICLE</span><span class="v flex ac" style="gap:6px">${C.tr("D", 390)}<span class="t-value">ZEPHYR</span></span></div>
       <div class="fact"><span class="t-label c-2">PRICE</span><span class="v chip yellow lg">$150,000</span></div>
       <div class="fact"><span class="t-label c-2">CASH AFTER</span><span class="v t-value">$850,000</span></div>
       <div class="fact"><span class="t-label c-2">GARAGE SPACES AFTER</span><span class="v t-value">1 / 2</span></div>`,
      [`<div class="btn" style="flex:1">${ic("close")}<span>CANCEL</span></div>`, `<div class="btn buy" style="flex:1"><span>BUY $150,000</span></div>`], "width:316px")));

  /* ---- c16 full map --------------------------------------------------------- */
  const mapBg = `<svg class="fill" viewBox="0 0 844 390" preserveAspectRatio="xMidYMid slice" style="width:100%;height:100%;display:block">
      <rect width="844" height="390" fill="#16142a"/>
      <path d="M0 300 Q200 250 380 310 T844 280 V390 H0Z" fill="#101a3a"/>
      <g fill="#201d3a"><rect x="60" y="30" width="150" height="90"/><rect x="250" y="20" width="120" height="120"/><rect x="420" y="50" width="180" height="80"/><rect x="640" y="30" width="150" height="130"/><rect x="100" y="160" width="190" height="80"/><rect x="340" y="170" width="140" height="90"/><rect x="530" y="170" width="200" height="80"/></g>
      <g stroke="#5a5680" fill="none"><path d="M-10 145 H860" stroke-width="12"/><path d="M230 -10 V300" stroke-width="12"/><path d="M400 -10 V330" stroke-width="8"/><path d="M620 -10 V300" stroke-width="12"/><path d="M-10 262 H500 L700 150 H860" stroke-width="9"/><path d="M40 -10 L40 280" stroke-width="6"/><path d="M500 145 V262" stroke-width="6"/></g>
      <path d="M318 262 H230 V145 H620 V92" stroke="#22E4FF" stroke-width="5" fill="none" stroke-linejoin="round"/>
      <circle cx="620" cy="92" r="9" fill="#FF2D95" stroke="#F3F0FF" stroke-width="2.5"/>
      <path d="M318 249 L329 274 L318 268 L307 274 Z" fill="#F3F0FF" stroke="#07060D" stroke-width="2" transform="rotate(-90 318 262)"/>
    </svg>`;
  const mi = (i, x, y) => `<div class="mapicon abs" style="left:${x}%;top:${y}%;width:22px;height:22px">${ic(i)}</div>`;
  const lg = (i, t) => `<div class="legendrow"><div class="mapicon">${ic(i)}</div><span class="t-label">${t}</span></div>`;
  F.c16 = () => C.page({ bg: mapBg, scrim: "hud" },
    mi("flag", 33, 30) + mi("flag", 80, 60) + mi("cart", 58, 16) + mi("wrench", 44, 62) + mi("garage", 88, 30) + mi("box", 66, 72) + mi("person", 50, 44) +
    `<div class="chip cyan abs" style="left:64%;top:27%">640 M</div>` +
    C.title("MAP", "AKANE DISTRICT") + `
    <div class="abs col" style="right:calc(var(--m) + var(--hx));top:calc(var(--m) + var(--hx));gap:calc(var(--hx) * 2 + var(--g))">${C.ibtn("close")}${C.ibtn("plus")}${C.ibtn("minus")}${C.ibtn("target")}${C.ibtn("info", "focus")}</div>
    <div class="panel abs col" style="left:var(--m);top:var(--tbh);width:150px;padding:6px 8px;gap:0">` +
      lg("flag", "RACE START") + lg("cart", "DEALERSHIP") + lg("wrench", "CUSTOMISATION") + lg("garage", "MY GARAGE") + lg("box", "JOB") + lg("person", "PLAYER") + `</div>
    <div class="abs flex ac" style="left:var(--m);bottom:var(--m);gap:var(--g)">${btn("CLEAR ROUTE", "close")}<div class="t-label c-2 shadow">DRAG TO PAN &middot; PINCH TO ZOOM &middot; TAP TO SET A ROUTE</div></div>`);

  /* ---- c17 world prompt + event card --------------------------------------- */
  F.c17 = () => C.page({ scene: "city", scrim: "hud" }, C.hud({ mode: "drive", speed: 0, boost: 100 }) + `
    <div class="c-event">
      <div class="flex ac" style="gap:6px"><div class="chk"></div><div class="t-tile">SHOWROOM LOOP</div></div>
      <div class="flex ac" style="gap:6px;margin-top:3px"><span class="t-label c-2">CIRCUIT &middot; 3 LAPS</span><span class="chip yellow">$10,000</span></div>
    </div>
    <div class="c-prompt hit">${ic("flag")}<span>START</span></div>`);

  /* ---- c18 toast + onboarding ----------------------------------------------- */
  const BY = "calc(var(--m) + 60px + var(--g) + var(--t) + var(--g) - 4px)";            /* boost hit box bottom, less the 4 px pad */
  const BX = "calc(var(--m) + var(--sw) + var(--g) / 2 - max(52px,var(--t)) / 2 - 4px)";
  const BS = "calc(max(52px,var(--t)) + 8px)";
  F.c18 = () => C.page({ scene: "city", scrim: "hud" }, C.hud({ mode: "drive", speed: 38, boost: 100 }) + `
    <div class="c-highlight" style="left:${BX};bottom:${BY};width:${BS};height:${BS}"></div>
    <div class="c-connector" style="left:calc(${BX} + ${BS});bottom:calc(${BY} + ${BS} / 2);width:14px;height:2px"></div>
    <div class="panel abs flex ac" style="left:calc(${BX} + ${BS} + 14px);bottom:calc(${BY} + 2px);width:236px;gap:8px;padding:8px;border-left:2px solid var(--pink)">
      <div class="t-body" style="flex:1;color:var(--white)">Hold <b>BOOST</b> for a burst of speed. It refills as you drive.</div>
      <div class="btn main nochev"><span>NEXT</span></div></div>
    <div class="c-objective">${ic("target", "c-pink")}<span class="t-label c-2">2 / 3</span><span class="t-value">ENTER AN EVENT</span></div>
    <div class="toastslot">${P.toast("Route set to Showroom Loop", "ok", "route")}</div>`);

  /* ---- c19 loading / start -------------------------------------------------- */
  const logo = () => `<div class="abs" style="left:var(--tbw);top:calc(var(--tbh) + 30px)"><div class="flex" style="gap:12px;align-items:center"><div class="titlemark" style="width:30px;height:104px;background:repeating-linear-gradient(135deg,var(--pink) 0 7px,transparent 7px 13px)"></div>
      <div class="t-title shadow" data-img style="font-size:60px;line-height:.92;white-space:normal;width:300px">PULSE RACERS</div></div>
      <div class="t-label c-2" style="margin-top:10px">LOGO ART UNCHANGED &middot; PLACEHOLDER BLOCK</div></div>`;
  F.c19a = () => C.page({ scene: "city", dim: 0.45, scrim: "hud" }, logo() + `
    <div class="abs" style="left:var(--m);right:var(--m);bottom:var(--m)">
      <div class="t-body" style="margin-bottom:6px;color:var(--white)">Tip: fit an engine, stabilisers and a boost unit before you drive out of the garage.</div>
      <div class="flex jb" style="margin-bottom:5px"><div class="t-value">LOADING WORLD</div><div class="t-value c-cyan">64%</div></div>
      <div class="progress"><i style="width:64%"></i></div></div>`);
  F.c19b = () => C.page({ scene: "city", dim: 0.3, scrim: "hud" }, logo() + C.actions([btn("PLAY", "wheel", "main lg")], "low"));

  window.F = F;
})();
