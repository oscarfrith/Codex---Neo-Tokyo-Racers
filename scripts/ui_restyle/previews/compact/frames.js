/* Compact (phone) frames c01..c19. Each F.<id>() draws one frame at the window size.
   Positions use the stage variables (--m margin, --t touch target, --g gap, --tbw/--tbh top-bar
   reserve) and edge anchors, so one description holds from 568x320 to 932x430. */
(function () {
  const F = {}, ic = P.ic, btn = C.btn;
  const Y2 = "calc(var(--tbh) + var(--t) + var(--g))";           /* content top under the tab row */
  const lab = (t, c = "c-2") => `<div class="t-label ${c}">${t}</div>`;

  /* ---- c01 / c02 free roam -------------------------------------------------- */
  F.c01 = () => C.page({ scene: "city", scrim: "hud", foot: 1 }, C.hud({ mode: "foot" }));
  F.c02 = () => C.page({ scene: "city", scrim: "hud" }, C.hud({ mode: "drive", speed: 142, boost: 64 }));

  /* ---- c03 car panel -------------------------------------------------------- */
  const cars = [["S", "SERAPH", 1], ["D", "STINGER"], ["D", "ZEPHYR"], ["C", "AURORA"], ["B", "ENDURA"], ["A", "ROSSO"], ["E", "PIERCER MK1"]];
  F.c03 = () => C.page({ scene: "city", scrim: "hud" }, C.hud({ mode: "foot", open: 0 }) + `
    <div class="panel abs" style="left:var(--m);top:calc(var(--m) + var(--t) + var(--g) + 32px + var(--g));bottom:var(--m);width:calc(120px * 4 + var(--g) * 3 + 20px);display:flex;flex-direction:column;gap:var(--g);overflow:hidden;padding-bottom:0">
      <div class="flex ac" style="gap:var(--g)">
        <div class="t-btnmain" style="margin-right:auto;font-weight:900">MY VEHICLES</div>
        <div class="btn sec">${lab("CLASS")}<span>ALL</span>${ic("down")}</div>
        <div class="btn sec">${lab("SORT")}<span>TIER</span>${ic("down")}</div>
        <div class="btn sec danger">DESPAWN</div>
      </div>
      <div class="flex" style="flex-wrap:wrap;gap:var(--g)">
        <div class="tile t7 mini"><div class="vis" style="top:14px;height:40px">${ic("plus", "c-white")}</div><div class="name t-tile7">BUY MORE</div></div>` +
        cars.map((c) => P.tile({ t7: 1, cls: "mini car", tier: c[0], name: c[1], vis: P.sil("car"), sel: c[2] })).join("") + `
      </div>
    </div>`);

  /* ---- c04 modals ----------------------------------------------------------- */
  const seg = (opts, on) => `<div class="segswitch">` + opts.map((o, i) => `<div class="opt t-label" style="font-weight:800">${o}</div>`.replace('class="opt', i === on ? 'class="opt on' : 'class="opt')).join("") + `</div>`;
  const setrow = (l, opts, on) => `<div class="setrow"><div class="lab t-label c-2">${l}</div>${seg(opts, on)}</div>`;
  F.c04a = () => C.page({ scene: "city", scrim: "hud", under: C.hud({ mode: "foot", open: 4 }) },
    C.modalSlot(C.modal("SETTINGS",
      setrow("TOUCH CONTROLS", ["ARROWS", "THUMBSTICK", "TILT"], 0) + setrow("MINIMAP", ["ROTATING", "NORTH UP"], 0) + setrow("PASSENGERS", ["FRIENDS", "ANYONE", "NOBODY"], 0),
      [btn("DONE", "tick", "main nochev")], "width:472px")));
  const pack = (cash, robux, best) => `<div class="tile" style="width:auto;flex:1;height:92px;opacity:.6;background:rgba(243,240,255,.10)">${best ? `<div class="corner chip white">BEST VALUE</div>` : ""}
      <div class="abs t-btnmain c-yellow" style="left:8px;bottom:27px;font-weight:900">${cash}</div><div class="abs t-label c-2" style="left:8px;bottom:8px">${robux}</div></div>`;
  F.c04b = () => C.page({ scene: "city", scrim: "hud", under: C.hud({ mode: "foot" }) },
    C.modalSlot(C.modal("GET CASH",
      `<div class="flex" style="gap:var(--g)">${pack("$10,000", "49 ROBUX")}${pack("$30,000", "99 ROBUX")}${pack("$75,000", "199 ROBUX")}${pack("$200,000", "399 ROBUX", 1)}</div>
       <div class="t-body" style="margin-top:8px">${ic("lock")} Cash packs are not available yet. Earn Cash by driving, racing and jobs.</div>`,
      [btn("CLOSE", "close")], "width:480px",
      `<div class="flex ac" style="margin-left:auto;gap:6px">${lab("BALANCE")}<div class="cash">${ic("coin")}<span class="t-status">$3,613,709</span></div></div>`)));

  /* ---- c05 / c06 race menu -------------------------------------------------- */
  const evrow = (kind, small, name, modes, laps, players, prize, dis) => `
    <div class="row${dis ? " dis" : ""}" style="height:60px;min-height:60px;padding:0 10px 0 0;gap:12px">
      <div style="width:96px;height:100%;background:rgba(7,6,13,.55);display:flex;align-items:center;justify-content:center;flex:none">${P.route(kind, "var(--white)", 78, 13)}</div>
      <div class="grow col" style="gap:4px">${lab(small)}<div class="t-tile">${name}</div></div>
      <div class="col" style="gap:5px;width:118px">${lab(modes)}<div class="flex ac t-label" style="gap:5px">${ic("laps")}${laps}<span style="width:6px"></span>${ic("players")}${players}</div></div>
      <div class="chip yellow lg" style="min-width:74px;justify-content:center">${prize}</div>${ic("right", "c-2")}
    </div>`;
  F.c05 = () => C.page({ scene: "city", scrim: "menu" },
    C.title("RACES") + P.tabs([{ l: "ALL EVENTS", on: 1 }, { l: "TIME TRIALS" }, { l: "RACES" }]) + C.status({ tier: "S", rating: 939 }) +
    `<div class="abs t-label c-2" style="right:var(--m);top:var(--tbh);height:var(--t);display:flex;align-items:center">5 EVENTS</div>
     <div class="abs col" style="left:var(--m);right:var(--m);top:calc(var(--tbh) + var(--t));bottom:calc(var(--m) + var(--t) + var(--g));gap:var(--g);overflow:hidden">` +
      evrow("loop", "CIRCUIT", "SHOWROOM LOOP", "TIME TRIAL &middot; RACE", "3", "2 TO 6", "$10,000") +
      evrow("sprint", "SPRINT", "WATERFRONT SPRINT", "TIME TRIAL &middot; RACE", "1", "2 TO 6", "$8,000") +
      evrow("canal", "CIRCUIT", "SHIFTED CANAL SPRINT", "RACE", "3", "2 TO 8", "$20,000") +
      evrow("sprint", "SPRINT", "HARBOUR RUN", "TIME TRIAL", "1", "1", "$6,000") +
      evrow("loop", "CIRCUIT", "AKANE RING", "RACE", "5", "2 TO 8", "$30,000") + `</div>` +
    C.actions([[btn("EXIT", "exit")]], 132));

  F.c06 = () => C.page({ scene: "city", scrim: "menu" },
    C.title("SHOWROOM LOOP") + C.status({ tier: "S", rating: 939 }) + `
    <div class="abs col" style="left:var(--m);right:calc(var(--m) + 236px + var(--g));top:calc(var(--tbh) + 2px);bottom:var(--m);gap:var(--g)">
      <div style="position:relative;height:84px;flex:none;background:url(../shared/bg/city.jpg) center 62%/cover;border-bottom:2px solid var(--pink)">
        <div class="fill" style="background:linear-gradient(0deg,rgba(7,6,13,.8),rgba(7,6,13,.15))"></div>
        <div class="abs t-label" style="left:10px;top:8px">EVENT 1 OF 2</div>
        <div class="abs t-tab shadow" style="left:10px;bottom:8px">CIRCUIT &middot; TIME TRIAL &middot; RACE</div>
      </div>
      <div class="panel" style="flex:1;display:flex;align-items:center;justify-content:center;min-height:0">${P.route("loop", "var(--white)", 250, 9)}</div>
    </div>
    <div class="panel abs" style="right:var(--m);top:calc(var(--tbh) + 2px);width:236px;padding:2px 10px">` +
      P.fact("route", "ROUTE", "CIRCUIT") + P.fact("laps", "LAPS", "3") + P.fact("checkpoint", "CHECKPOINTS", "17") + P.fact("players", "PLAYERS", "2 TO 6") +
      `<div class="fact"><span class="t-label c-2">PRIZE</span><span class="v chip yellow lg">$10,000</span></div></div>` +
    C.actions([[btn("BACK", "back", "sec"), btn("SET ROUTE", "route", "sec")], [btn("TELEPORT", "pin", "main")]], 236));

  /* ---- c07 race entry ------------------------------------------------------- */
  const medalrow = (k, name, time, yours) => `<div class="row ${yours ? "you" : "bare"}" style="min-height:26px;height:26px;border-bottom:0;padding:0 8px;gap:8px">${P.medal(k)}<span class="t-label" style="font-weight:800">${name}</span>${yours ? `<span class="t-label c-pink">YOURS</span>` : ""}<span class="right t-value">${time}</span></div>`;
  F.c07 = () => C.page({ scene: "city", scrim: "menu" },
    C.title("SHOWROOM LOOP") + P.tabs([{ l: "TIME TRIAL", on: 1 }, { l: "RACE" }]) + C.status({ tier: "S", rating: 939 }) + `
    <div class="abs flex" style="right:var(--m);top:var(--tbh);gap:var(--g)">` +
      [["E", "done"], ["D", "done"], ["C", "on"], ["B", ""], ["A", "locked"], ["S", "locked"]].map((t) => `<div class="tierbtn ${t[1]}">${t[0]}</div>`).join("") + `</div>
    <div class="panel abs col" style="left:var(--m);right:calc(var(--m) + 244px + var(--g) + 224px + var(--g));top:${Y2};bottom:var(--m);padding:8px 8px 8px">
      ${lab("3 LAPS &middot; 17 CP")}
      <div style="flex:1;display:flex;align-items:center;justify-content:center;min-height:0;overflow:hidden">${P.route("loop", "var(--cyan)", 150, 11)}</div>
      <div class="flex ac" style="gap:var(--g)">${C.ibtn("minus")}<div class="t-sect" style="flex:1;text-align:center">3</div>${C.ibtn("plus")}</div>
    </div>
    <div class="abs col" style="right:calc(var(--m) + 244px + var(--g));width:224px;top:${Y2};bottom:var(--m);gap:var(--g)">
      <div class="panel" style="padding:8px 10px">${lab("YOUR BEST &middot; STINGER")}<div class="num" style="font-size:var(--fs-timer);margin-top:8px">01:03.275</div></div>
      <div class="panel" style="flex:1;padding:6px 2px;display:flex;flex-direction:column;justify-content:space-around">` +
        medalrow("plat", "PLATINUM", "00:58.000") + medalrow("", "GOLD", "01:02.000", 1) + medalrow("silver", "SILVER", "01:08.000") + medalrow("bronze", "BRONZE", "01:15.000") + `</div>
    </div>
    <div class="panel abs" style="right:var(--m);width:244px;top:${Y2};bottom:calc(var(--m) + var(--t) * 2 + var(--g) * 2);padding:8px 10px">
      ${lab("TIER C &middot; PLATINUM PRIZE")}
      <div class="chip yellow" style="height:30px;font-size:var(--fs-sect);font-weight:900;margin-top:8px;padding:0 9px 0 8px">$25,000</div>
      <div class="t-label c-2" style="margin-top:8px">DAILY BONUS READY</div>
      <div class="num abs" style="right:10px;bottom:10px;font-size:var(--fs-pos)">C</div>
    </div>` +
    C.actions([[btn("EXIT", "exit", "sec"), btn("RECORDS", "trophy", "sec")], [btn("CHOOSE VEHICLE", "car", "main")]], 244));

  /* ---- c08 / c09 race ------------------------------------------------------- */
  const boardrow = (p, name, gap, you) => `<div class="row ${you ? "you" : ""}"><span class="p t-label" style="font-weight:800">${p}</span><span class="t-label" style="font-weight:800">${name}</span><span class="right t-label c-2">${gap}</span></div>`;
  const board = () => `<div class="c-board">${boardrow(1, "NEONRIDER", "&minus;1.8")}${boardrow(2, "YOU", "SERAPH", 1)}${boardrow(3, "CYBERWAVE", "+0.6")}${boardrow(4, "NIGHTDRIFT", "+2.3")}</div>`;
  const sessionBtns = () => `<div class="abs flex" style="right:var(--m);top:calc(var(--m) + 98px + var(--g));width:196px;gap:var(--g)">
      <div class="btn sec" style="flex:1;padding:0 4px;gap:4px">${ic("undo")}<span>RESET</span></div><div class="btn sec danger" style="flex:1;padding:0 4px;gap:4px">${ic("exit")}<span>QUIT</span></div></div>`;
  F.c08 = () => C.page({ scene: "race", scrim: "hud" }, `
    <div class="c-leftzone">
      <div class="flex" style="align-items:flex-start;gap:3px"><span class="num shadow" style="font-size:var(--fs-pos)">2</span><span class="t-sect shadow" style="margin-top:1px">ND</span><span class="t-value c-2 shadow" style="align-self:flex-end;margin-left:2px">/ 8</span></div>
      <div class="chip lg ink" style="margin-top:8px;border-left:2px solid var(--cyan);font-size:var(--fs-value)">LAP 2 / 3</div>
    </div>
    <div class="c-timer"><div class="box"><div class="num" style="font-size:var(--fs-timer)">01:03.275</div></div>
      <div class="chip cyan">LAP &minus;0.412</div>
      <div class="pips">${Array.from({ length: 12 }, (_, i) => `<i class="pip ${i < 7 ? "on" : ""}"></i>`).join("")}</div></div>` +
    board() + sessionBtns() + C.gauge(187, 30) + C.touch({ boost: 30, on: ["Accelerator", "TurnRight"] }));

  F.c09 = () => C.page({ scene: "race", scrim: "hud", dim: 0.25 }, `
    <div class="abs col" style="left:0;right:0;top:calc(var(--tbh) + 2px);align-items:center">
      <div class="t-sect shadow">GET READY</div>
      <div class="num" style="font-size:var(--fs-count);margin-top:10px;text-shadow:0 3px 0 rgba(7,6,13,.55)">3</div>
      <div style="width:120px;height:2px;background:var(--pink);margin-top:8px"></div>
      <div class="t-label c-2 shadow" style="margin-top:7px">SHOWROOM LOOP &middot; RACE &middot; 3 LAPS</div>
    </div>
    <div class="c-leftzone"><div class="chip lg ink" style="border-left:2px solid var(--cyan);font-size:var(--fs-value)">GRID 2 / 8</div></div>` +
    board() + C.gauge(0, 100) + C.touch({ boost: 100, off: 1 }));

  /* ---- c10 results ---------------------------------------------------------- */
  const hero = (l, v, c) => `<div>${`<div class="t-value shadow">${l}</div>`}<div class="num ${c}" style="font-size:var(--fs-hero);margin-top:8px;text-shadow:0 2px 0 rgba(7,6,13,.5)">${v}</div></div>`;
  const cell = (l, v) => `<div style="flex:1;padding:6px 10px">${lab(l)}<div class="t-value" style="margin-top:5px">${v}</div></div>`;
  const resrow = (p, name, time, you) => `<div class="row ${you ? "you" : "bare"}" style="min-height:24px;height:24px;padding:0 8px 0 0;gap:8px;border-bottom:0"><span class="t-label" style="font-weight:800;width:22px;text-align:center">${p}</span><span class="t-label" style="font-weight:800">${name}</span><span class="right t-label ${you ? "" : "c-2"}">${time}</span></div>`;
  F.c10 = () => C.page({ scene: "race", scrim: "menu" },
    C.title("RACE COMPLETE") + `
    <div class="abs t-label c-2" style="left:var(--tbw);top:calc(var(--tbh) - 6px)">SHIFTED CANAL SPRINT &middot; 3 LAPS &middot; SERAPH</div>
    <div class="abs col" style="left:var(--m);right:calc(var(--m) + 240px + 16px);top:calc(var(--tbh) + 24px);gap:14px;align-items:center">
      <div class="flex" style="gap:28px">${hero("BANKED", "$20,000", "c-yellow")}${hero("DRIVER XP", "+120", "c-pink")}</div>
      <div class="panel flush flex" style="align-self:stretch">${cell("FINISH", "2ND OF 8")}${cell("TIME", "03:11.842")}${cell("BEST LAP", "01:02.966")}</div>
    </div>
    <div class="panel abs" style="right:var(--m);top:var(--m);width:240px;bottom:calc(var(--m) + var(--t) + var(--g));padding:8px 2px 4px;overflow:hidden">
      <div class="t-label c-2" style="padding:0 8px 5px">RESULTS</div>` +
      resrow(1, "NEONRIDER", "03:10.021") + resrow(2, "YOU", "03:11.842", 1) + resrow(3, "CYBERWAVE", "+0.612") + resrow(4, "NIGHTDRIFT", "+2.318") + resrow(5, "AKIRA_77", "+4.901") + resrow(6, "VOLTLINE", "+7.440") + resrow(7, "KOSMO", "+9.027") + resrow(8, "DRIFTCAT", "DNF") + `
    </div>
    <div class="abs flex" style="left:var(--m);right:var(--m);bottom:var(--m);gap:var(--g);justify-content:center">${btn("RACE AGAIN", "loop")}${btn("CONTINUE", "", "main")}</div>`);

  /* ---- c11..c15 garage ------------------------------------------------------ */
  const gtabs = (on) => [{ l: "PARTS", i: "wrench", on: on === 0 }, { l: "UPGRADES", i: "upgrade", on: on === 1 }, { l: "PAINT", i: "brush", on: on === 2 }];
  const head = (h, extra = "") => `<div class="t-sect shadow">${h}</div>${extra}`;
  const sw = (a, b) => `<div class="switch"><div class="opt t-tab on hit">${a}</div><div class="opt t-tab hit">${b}</div></div>`;
  const dealer = () => C.garage({
    title: "DEALERSHIP", tabs: [{ l: "ALL" }, { l: "EXOTIC", on: 1 }, { l: "PIERCER" }, { l: "MUSCLE" }], status: { garage: "0 / 2", plus: 1, rank: 1, cash: "$1.00M" },
    stat: { name: "ZEPHYR", badge: "<span>D</span><span>390</span>", sub: "EXOTIC &middot; TIER D", stats: [["SPEED", 77], ["ACCEL", 74], ["HANDLING", 74], ["DRIFT", 72], ["BRAKING", 73], ["BOOST", 72]] },
    head: head("EXOTIC 2/6", sw("FOR SALE", "OWNED")),
    rail: [["E", "PI 220", "STINGER", 0, "OWNED"], ["D", "PI 390", "ZEPHYR", "$150,000"], ["C", "PI 540", "AURORA", "$440,000"], ["B", "PI 675", "ENDURA", "$1.40M", 0, 1], ["A", "PI 800", "ROSSO", "$4.40M", 0, 1]]
      .map((c, i) => P.tile({ t7: 1, cls: "car", tier: c[0], sub: c[1], name: c[2], price: c[3] || null, unaff: c[5], corner: c[4] ? { t: c[4] } : null, vis: P.sil("car"), sel: i === 1 })).join(""),
    actions: [[btn("EXIT", "exit", "sec")], [btn("BUY $150,000", "", "buy")]],
  });
  F.c11 = () => C.page({ scene: "dealer", scrim: "garage" }, dealer());

  const slots = [["01", "BULL NOSE", "FRONT BODY", "nose"], ["02", "STANDARD", "REAR BODY", ""], ["03", "STANDARD", "FRONT ENGINE", "eng"], ["04", "STANDARD", "REAR ENGINE", "eng"], ["05", "STANDARD", "DRIFT THRUSTERS", ""], ["06", "STANDARD", "OVERDRIVE", ""], ["07", "SPINE WING", "WING", "wing"]];
  F.c12 = () => C.page({ scene: "garage", scrim: "garage" }, C.garage({
    title: "CUSTOMISE", tabs: gtabs(0),
    stat: { name: "STINGER", badge: "<span>D</span><span>316</span>", sub: "EXOTIC &middot; 7 OF 7 PARTS FITTED", stats: C.STATS },
    head: head("PARTS 7/7", `<div class="t-label c-2 shadow">FRONT ENGINE &middot; STANDARD</div>`),
    rail: slots.map((s, i) => P.tile({ t7: 1, idx: s[0], corner: { t: "FITTED" }, sub: s[1], name: s[2], vis: P.sil(s[3]), sel: i === 2, two: s[2].length > 12 })).join(""),
    actions: [[btn("BACK", "back", "sec")], [btn("DRIVE", "wheel", "main")]],
  }));

  F.c13 = () => C.page({ scene: "garage", scrim: "garage" }, C.garage({
    title: "CUSTOMISE", tabs: gtabs(0),
    stat: { name: "STINGER", badge: "<span>D</span><span>318</span>", sub: "PREVIEW &middot; SPINE WING EVO", stats: [["SPEED", 80], ["ACCEL", 74], ["HANDLING", 66, 3], ["DRIFT", 63, 2], ["BRAKING", 62], ["BOOST", 61]] },
    head: head("WING 3/9", sw("SHOP", "OWNED")),
    rail: [["STD", "SPINE &middot; OWNED 1", "SPINE WING", 0, "FITTED"], ["GT", "SPINE &middot; OWNED 0", "SPINE WING", "$3,000"], ["EVO", "SPINE &middot; OWNED 1", "SPINE WING", "$6,000"], ["STD", "NEEDS ZEPHYR", "BRIDGE WING", "$42,000", 0, 1], ["GT", "NEEDS ZEPHYR", "BRIDGE WING", "$84,000", 0, 1]]
      .map((c, i) => P.tile({ t7: 1, variant: c[0], sub: c[1], name: c[2], price: c[3] || null, corner: c[4] ? { t: c[4] } : null, vis: P.sil("wing"), sel: i === 2, locked: c[5], unaff: c[5] })).join(""),
    actions: [[btn("BACK", "back", "sec"), btn("DRIVE", "wheel", "sec")], [btn("EQUIP", "tick", "main")]],
  }));

  const slider = (l, v, cls, pos) => `<div class="panel" style="flex:1;height:var(--t);padding:6px 10px 0"><div class="flex jb">${lab(l)}<span class="t-label">${v}</span></div><div class="slider ${cls}" style="margin-top:10px"><b style="left:${pos}%"></b></div></div>`;
  const SW = ["#F3F0FF", "#232A6B", "#FF8A80", "#FFD180", "#B9F6CA", "#80D8FF", "#B388FF", "#3A3A44"];
  F.c14 = () => C.page({ scene: "garage", scrim: "garage" },
    C.title("CUSTOMISE") + P.tabs(gtabs(2)) + C.status({ garage: "3 / 4", plus: 1 }) + `
    <div class="c-railhead" style="bottom:calc(var(--m) + var(--t) * 2 + var(--g) + 2px);align-items:center;gap:6px">
      <div class="t-sect shadow">AREA 1/10</div>
      <div class="hit flex ac" style="width:var(--t);height:var(--t);justify-content:center;margin-left:4px">${ic("left", "t-sect")}</div>
      <div class="t-tab shadow" style="min-width:104px;text-align:center">WHOLE CAR</div>
      <div class="hit flex ac" style="width:var(--t);height:var(--t);justify-content:center">${ic("right", "t-sect")}</div>
    </div>
    <div class="abs col" style="left:var(--m);right:calc(var(--m) + 212px + var(--g));bottom:var(--m);gap:var(--g)">
      <div class="flex" style="gap:var(--g);overflow:hidden">
        <div style="flex:none;width:calc(66px * 4 + var(--g) * 3)">${seg(["PRIMARY", "SECOND", "DETAIL", "NEON"], 0)}</div>` +
        SW.map((c, i) => `<div class="swatch ${i === 1 ? "on" : ""}" style="background:${c}"></div>`).join("") + `
      </div>
      <div class="flex" style="gap:var(--g)">${slider("HUE", "236&deg;", "hue", 66)}${slider("SATURATION", "52%", "sat", 52)}${slider("BRIGHTNESS", "26%", "bri", 26)}</div>
    </div>` +
    C.actions([[btn("BACK", "back", "sec"), btn("DRIVE", "wheel", "sec")], [btn("APPLY", "tick", "main")]]));

  F.c15 = () => C.page({ scene: "dealer", scrim: "garage", under: dealer() },
    C.modalSlot(C.modal("BUY ZEPHYR?",
      `<div class="fact"><span class="t-label c-2">VEHICLE</span><span class="v flex ac" style="gap:6px"><span class="tierrating"><span>D</span><span>390</span></span><span class="t-value">ZEPHYR</span></span></div>
       <div class="fact"><span class="t-label c-2">PRICE</span><span class="v chip yellow lg">$150,000</span></div>
       <div class="fact"><span class="t-label c-2">CASH AFTER</span><span class="v t-value">$850,000</span></div>
       <div class="fact"><span class="t-label c-2">GARAGE SPACES AFTER</span><span class="v t-value">1 / 2</span></div>`,
      [`<div class="btn" style="flex:1">${ic("close")}<span>CANCEL</span></div>`, `<div class="btn buy" style="flex:1"><span>BUY $150,000</span></div>`], "width:392px")));

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
  const mi = (i, x, y) => `<div class="mapicon abs" style="left:${x}%;top:${y}%;width:26px;height:26px">${ic(i)}</div>`;
  const lg = (i, t) => `<div class="legendrow"><div class="mapicon">${ic(i)}</div><span class="t-label">${t}</span></div>`;
  F.c16 = () => C.page({ bg: mapBg, scrim: "hud" },
    mi("flag", 33, 30) + mi("flag", 80, 60) + mi("cart", 58, 16) + mi("wrench", 44, 62) + mi("garage", 88, 30) + mi("box", 66, 72) + mi("person", 50, 44) +
    `<div class="chip cyan abs" style="left:64%;top:27%">640 M</div>` +
    C.title("MAP", "AKANE DISTRICT") + `
    <div class="abs flex" style="right:var(--m);top:var(--m);gap:var(--g)"><div class="btn sec focus">${ic("info")}<span>KEY</span></div>${C.ibtn("close")}</div>
    <div class="abs col" style="right:var(--m);top:calc(var(--m) + var(--t) + var(--g));gap:var(--g)">${C.ibtn("plus")}${C.ibtn("minus")}${C.ibtn("target")}${C.ibtn("map")}</div>
    <div class="panel abs col" style="left:var(--m);top:calc(var(--tbh) + 2px);width:178px;padding:8px 10px;gap:0">
      <div class="t-value" style="margin-bottom:5px">MAP KEY</div>` +
      lg("flag", "RACE START") + lg("cart", "DEALERSHIP") + lg("wrench", "CUSTOMISATION") + lg("garage", "MY GARAGE") + lg("box", "JOB") + lg("person", "PLAYER") +
      `<div class="btn sec" style="margin-top:var(--g);padding:0 4px;gap:4px">${ic("close")}<span>CLEAR ROUTE</span></div></div>
    <div class="abs" style="left:calc(var(--m) + 178px + var(--g));right:calc(var(--m) + var(--t) + var(--g));bottom:var(--m);display:flex;justify-content:center"><div class="chip ink lg" style="font-weight:600">DRAG TO PAN &middot; PINCH TO ZOOM &middot; TAP TO SET A ROUTE</div></div>`);

  /* ---- c17 world prompt + event card --------------------------------------- */
  F.c17 = () => C.page({ scene: "city", scrim: "hud" }, C.hud({ mode: "drive", speed: 0, boost: 100 }) + `
    <div class="c-leftzone" style="right:calc(var(--m) + 104px + var(--g) * 6 + var(--t) * 5);max-width:240px"><div class="panel flush">
      <div style="padding:8px 10px 8px"><div class="t-tile">SHOWROOM LOOP</div><div class="t-label c-2" style="margin-top:5px">CIRCUIT RACE &middot; 3 LAPS</div></div>
      <div class="chk abs" style="right:0;top:0"></div>
      <div class="flex" style="height:42px">
        <div style="flex:1;background:var(--white);color:var(--ink);padding:6px 6px 0 8px"><div class="t-label">YOU</div><div class="t-status" style="margin-top:3px">S 939</div></div>
        <div style="flex:1;padding:6px 6px 0 8px"><div class="t-label c-2">ENTRY</div><div class="t-status" style="margin-top:3px">OPEN</div></div>
        <div style="background:var(--yellow);color:var(--ink);padding:6px 8px 0 8px"><div class="t-label">PRIZE</div><div class="t-status" style="margin-top:3px">$10,000</div></div>
      </div></div></div>
    <div class="promptstack"><div class="prompt touch">${ic("flag", "t-sect")}<span class="t-btnmain">START</span><span class="obj t-label c-2">SHOWROOM LOOP</span></div></div>`);

  /* ---- c18 toast + onboarding ----------------------------------------------- */
  F.c18 = () => C.page({ scene: "city", scrim: "hud" }, C.hud({ mode: "drive", speed: 38, boost: 100 }) + `
    <div class="c-highlight" style="left:calc(var(--m) - 4px);bottom:calc(var(--m) + 64px + var(--g) + max(52px,var(--t)) + var(--g) - 4px);width:calc(88px * 2 + var(--g) + 8px);height:calc(var(--t) + 8px)"></div>
    <div class="c-connector" style="left:calc(var(--m) + 88px * 2 + var(--g) + 4px);bottom:calc(var(--m) + 64px + var(--g) + max(52px,var(--t)) + var(--g) + var(--t) / 2);width:16px;height:2px"></div>
    <div class="panel abs flex ac" style="left:calc(var(--m) + 88px * 2 + var(--g) + 20px);bottom:calc(var(--m) + 64px + var(--g) + max(52px,var(--t)) + var(--g) - 10px);width:262px;gap:10px;padding:10px;border-left:2px solid var(--pink)">
      <div class="t-body" style="flex:1;color:var(--white)">Hold <b>BOOST</b> for a burst of speed. It refills as you drive.</div>
      <div class="btn main" style="padding:0 12px"><span>NEXT</span></div></div>
    <div class="c-leftzone"><div class="c-objective">${ic("target", "c-pink t-sect")}<div><div class="t-label c-2">OBJECTIVE 2 OF 3</div><div class="t-value" style="margin-top:4px">ENTER AN EVENT</div></div></div></div>
    <div class="toastslot">${P.toast("Route set to Showroom Loop", "ok", "route")}</div>`);

  /* ---- c19 loading / start -------------------------------------------------- */
  const logo = () => `<div class="abs" style="left:var(--tbw);top:calc(var(--tbh) + 34px)"><div class="flex" style="gap:12px;align-items:center"><div class="titlemark" style="width:30px;height:104px;background:repeating-linear-gradient(135deg,var(--pink) 0 7px,transparent 7px 13px)"></div>
      <div class="t-title shadow" style="font-size:60px;line-height:.92;white-space:normal;width:300px">PULSE RACERS</div></div>
      <div class="t-label c-2" style="margin-top:10px">LOGO ART UNCHANGED &middot; PLACEHOLDER BLOCK</div></div>`;
  F.c19a = () => C.page({ scene: "city", dim: 0.45, scrim: "hud" }, logo() + `
    <div class="abs" style="left:var(--m);right:var(--m);bottom:var(--m)">
      <div class="t-body" style="margin-bottom:8px;color:var(--white)">Tip: fit an engine, stabilisers and a boost unit before you drive out of the garage.</div>
      <div class="flex jb" style="margin-bottom:6px"><div class="t-value">LOADING WORLD</div><div class="t-value c-cyan">64%</div></div>
      <div class="progress" style="height:4px"><i style="width:64%"></i></div></div>`);
  F.c19b = () => C.page({ scene: "city", dim: 0.3, scrim: "hud" }, logo() + C.actions([[btn("PLAY", "wheel", "main")]], 212));

  window.F = F;
})();
