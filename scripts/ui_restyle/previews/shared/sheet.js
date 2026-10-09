/* helpers for annotated sheets (component sheet, state sheets) */
window.L = (t) => `<div class="sheetlabel">${t}</div>`;
window.cell = (label, html) => `<div class="cell">${html}${L(label)}</div>`;
window.sheetHead = (t, sub) => `<div class="abs t-sect" style="left:60px;top:34px;font-size:40px">${t} <span class="t-label c-2" style="margin-left:14px">${sub || ""}</span></div>`;
document.head.insertAdjacentHTML("beforeend", `<style>
.sec{position:absolute;left:60px}
.cell{display:flex;flex-direction:column;gap:10px;align-items:flex-start}
.rowx{display:flex;gap:14px;align-items:flex-end}
.divider{position:absolute;top:0;bottom:0;width:4px;background:#000}
</style>`);
