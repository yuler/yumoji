const $ = (id) => document.getElementById(id);
const DAY = 864e5;

const state = {
  entries: new Map(), // "YYYY-M-D" -> [{ emoji, name, kcal, intro, isFood, time }]
  viewMonth: startOfMonth(new Date()),
  sample: SAMPLES[0],
  subject: null, // 选中的主体
  analysis: "loading", // "loading" | "loaded" | "failed"
  kcal: null, // 用户可改的热量
  failNext: false,
  timers: [],
};

function startOfMonth(d) { return new Date(d.getFullYear(), d.getMonth(), 1); }
const keyOf = (d) => `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
const sameDay = (a, b) => keyOf(a) === keyOf(b);
const fmtKcal = (k) => (k == null ? "" : `约 ${Math.max(0, k)} 千卡`);
const dayKcal = (list) => list.reduce((s, e) => s + (e.kcal || 0), 0);
const kcalSummary = (list) => (list.some((e) => e.kcal != null) ? `合计${fmtKcal(dayKcal(list))}` : "还没有热量估算");
const weekday = (d) => `星期${"日一二三四五六"[d.getDay()]}`;
const hhmm = (d) => `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;

function seedHistory() {
  const today = new Date();
  HISTORY_SEED.forEach(([ago, items]) => {
    const d = new Date(today - ago * DAY);
    state.entries.set(keyOf(d), items.map(([emoji, name, kcal], i) => ({
      emoji, name, kcal, intro: "", isFood: true, time: `${String(8 + i * 5).padStart(2, "0")}:${i ? "40" : "15"}`,
    })));
  });
}

function show(id) {
  document.querySelectorAll(".screen").forEach((s) => s.classList.toggle("active", s.id === id));
  document.querySelector(".phone").classList.toggle("dark", id === "camera");
}
function later(fn, ms) { state.timers.push(setTimeout(fn, ms)); }
function clearTimers() { state.timers.forEach(clearTimeout); state.timers = []; }

function toast(msg) {
  const t = $("toast");
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (t.hidden = true), 2000);
}

function stickerEl(emoji, cls = "") {
  const el = document.createElement("span");
  el.className = `sticker ${cls}`;
  el.textContent = emoji;
  return el;
}

/* 日历 */
function renderCalendar() {
  const now = new Date();
  $("today-date").textContent = `${now.getMonth() + 1} 月 ${now.getDate()} 日 · ${weekday(now)}`;

  const todayList = state.entries.get(keyOf(now)) || [];
  const strip = $("today-stickers");
  strip.innerHTML = "";
  if (todayList.length) {
    todayList.slice(-4).forEach((e, i) => {
      const s = stickerEl(e.emoji);
      s.style.transform = `rotate(${[-8, 6, -4, 9][i]}deg)`;
      strip.appendChild(s);
    });
  } else {
    strip.appendChild(stickerEl("🍙", "ghost"));
  }
  $("today-title").textContent = todayList.length ? `今天收了 ${todayList.length} 枚` : "今天还没有贴纸";
  $("today-hint").textContent = todayList.length ? kcalSummary(todayList) : "拍下这一餐，收成第一枚";

  const m = state.viewMonth;
  $("month-title").textContent = `${m.getFullYear()} 年 ${m.getMonth() + 1} 月`;
  $("next-month").disabled = sameDay(m, startOfMonth(now));

  const days = $("days");
  days.innerHTML = "";
  for (let i = 0; i < m.getDay(); i++) days.appendChild(document.createElement("span"));
  const count = new Date(m.getFullYear(), m.getMonth() + 1, 0).getDate();
  for (let n = 1; n <= count; n++) {
    const d = new Date(m.getFullYear(), m.getMonth(), n);
    const list = state.entries.get(keyOf(d)) || [];
    const cell = document.createElement("button");
    cell.className = "day";
    cell.classList.toggle("today", sameDay(d, now));
    cell.classList.toggle("future", d > now);
    cell.innerHTML = `<i>${n}</i>`;
    if (list.length) {
      cell.appendChild(stickerEl(list[0].emoji, "mini"));
      if (list.length > 1) cell.insertAdjacentHTML("beforeend", `<em>${list.length}</em>`);
    }
    if (d <= now) cell.onclick = () => openDay(d);
    days.appendChild(cell);
  }
}

function moveMonth(delta) {
  const m = state.viewMonth;
  state.viewMonth = new Date(m.getFullYear(), m.getMonth() + delta, 1);
  renderCalendar();
}

function openDay(d) {
  const list = state.entries.get(keyOf(d)) || [];
  $("day-title").textContent = `${d.getMonth() + 1} 月 ${d.getDate()} 日 · ${weekday(d)}`;
  $("day-sub").textContent = list.length ? `${list.length} 枚贴纸 · ${kcalSummary(list)}` : "";
  $("day-empty").hidden = list.length > 0;
  const ul = $("entries");
  ul.innerHTML = "";
  list.forEach((e) => {
    const li = document.createElement("li");
    li.appendChild(stickerEl(e.emoji));
    li.insertAdjacentHTML("beforeend", `<div><b>${e.name}</b><span>${e.time}${e.intro ? " · " + e.intro : ""}</span></div>
      <em>${e.kcal == null ? "—" : e.kcal + " 千卡"}</em>`);
    ul.appendChild(li);
  });
  $("day-sheet").hidden = false;
}

/* 拍照 */
function openCamera() {
  clearTimers();
  renderSamples();
  renderPlate($("cam-plate"), state.sample);
  show("camera");
}

function renderSamples() {
  const box = $("samples");
  box.innerHTML = "";
  SAMPLES.forEach((s) => {
    const b = document.createElement("button");
    b.className = "chip";
    b.classList.toggle("on", s === state.sample);
    b.textContent = s.label;
    b.onclick = () => { state.sample = s; renderSamples(); renderPlate($("cam-plate"), s); };
    box.appendChild(b);
  });
  $("cam-hint").textContent = "把食物放在画面中间 · 下面可换样例照片";
}

function renderPlate(el, sample) {
  el.style.background = `radial-gradient(circle at 50% 45%, #fffdf8 0 34%, #f1e6d6 35% 40%, transparent 41%), linear-gradient(160deg, ${sample.table[0]}, ${sample.table[1]})`;
  el.innerHTML = "";
  sample.subjects.forEach((s, i) => {
    const food = document.createElement("span");
    food.className = "food";
    food.textContent = s.emoji;
    food.style.setProperty("--x", `${s.x || 0}px`);
    food.style.setProperty("--y", `${s.y || 0}px`);
    if (s.size) food.style.fontSize = `${s.size}px`;
    food.dataset.i = i;
    el.appendChild(food);
  });
}

function takePhoto(flash) {
  if (flash) {
    $("viewfinder").classList.add("flash");
    setTimeout(() => $("viewfinder").classList.remove("flash"), 250);
  }
  setTimeout(startCutout, flash ? 260 : 0);
}

/* 抠图与确认 */
function startCutout() {
  const sample = state.sample;
  const plate = $("cut-plate");
  renderPlate(plate, sample);
  state.subject = null;
  $("cut-stage").classList.remove("done");
  $("scan").hidden = false;
  $("cut-title").textContent = "正在抠图…";
  $("cut-sub").textContent = "把食物从照片里抠出来";
  const btn = $("cut-confirm");
  btn.disabled = true;
  btn.textContent = "就这块";
  btn.onclick = confirmSubject;
  show("cutout");

  later(() => {
    $("scan").hidden = true;
    $("cut-stage").classList.add("done");
    const foods = [...plate.querySelectorAll(".food")];
    if (!foods.length) {
      $("cut-title").textContent = "没找到可以做成贴纸的食物";
      $("cut-sub").textContent = "换个角度，或者让食物在画面里更突出一些";
      btn.disabled = false;
      btn.textContent = "换一张照片";
      btn.onclick = openCamera;
      return;
    }
    foods.forEach((f) => (f.onclick = () => pickSubject(foods, +f.dataset.i)));
    if (foods.length > 1) {
      $("cut-title").textContent = `找到 ${foods.length} 样，点选要哪块`;
      $("cut-sub").textContent = "一次收一枚，另一样可以再拍一次";
    } else {
      $("cut-title").textContent = "抠好了";
      $("cut-sub").textContent = "确认后 AI 会认出菜名和大致热量";
    }
    pickSubject(foods, 0);
  }, 1300);
}

function pickSubject(foods, i) {
  state.subject = state.sample.subjects[i];
  foods.forEach((f, j) => f.classList.toggle("picked", j === i));
  $("cut-stage").classList.toggle("multi", foods.length > 1);
  $("cut-confirm").disabled = false;
}

function confirmSubject() {
  const stage = $("res-stage");
  stage.innerHTML = "";
  stage.appendChild(stickerEl(state.subject.emoji, "hero pop"));
  state.kcal = state.subject.kcal;
  runAnalysis();
  show("result");
}

/* 结果 */
function runAnalysis() {
  state.analysis = "loading";
  renderAnalysis();
  const fail = state.failNext;
  later(() => {
    state.analysis = fail ? "failed" : "loaded";
    renderAnalysis();
  }, 1400);
}

function renderAnalysis() {
  const card = $("analysis");
  const s = state.subject;
  if (state.analysis === "loading") {
    card.innerHTML = `<div class="loading"><i class="dots"><b></b><b></b><b></b></i>正在认这是什么好吃的…</div>`;
  } else if (state.analysis === "failed") {
    card.innerHTML = `<div class="row"><b class="pending">待识别</b><button class="link" id="retry-btn">↻ 重试</button></div>
      <p class="intro">贴纸已经抠好，文字可以晚点再识别</p>`;
    $("retry-btn").onclick = () => { state.failNext = false; $("fail-toggle").checked = false; runAnalysis(); };
  } else {
    card.innerHTML = `<div class="row"><b class="name">${s.name}</b>
      ${s.isFood ? `<button class="kcal" id="kcal-btn">${fmtKcal(state.kcal)} ✎</button>` : ""}</div>
      ${s.isFood ? "" : `<p class="warn">这个好像不是吃的</p>`}
      <p class="intro">${s.intro.slice(0, 40)}</p>`;
    if (s.isFood) $("kcal-btn").onclick = openKcal;
  }
}

function openKcal() {
  $("kcal-input").value = state.kcal ?? "";
  $("kcal-alert").hidden = false;
  $("kcal-input").focus();
}

function saveKcal() {
  const v = parseInt($("kcal-input").value, 10);
  if (!Number.isNaN(v)) state.kcal = Math.min(5000, Math.max(0, v));
  $("kcal-alert").hidden = true;
  renderAnalysis();
}

function saveSticker() {
  clearTimers();
  const now = new Date();
  const s = state.subject;
  const loaded = state.analysis === "loaded";
  const key = keyOf(now);
  const list = state.entries.get(key) || [];
  list.push({
    emoji: s.emoji,
    name: loaded ? s.name : "待识别",
    kcal: loaded && s.isFood ? state.kcal : null,
    intro: loaded ? s.intro : "",
    isFood: s.isFood,
    time: hhmm(now),
  });
  state.entries.set(key, list);
  state.viewMonth = startOfMonth(now);
  renderCalendar();
  show("calendar");
  document.querySelector(".day.today")?.classList.add("bump");
  toast(`收进今天啦 · 今天第 ${list.length} 枚`);
}

/* 绑定 */
$("snap-btn").onclick = openCamera;
$("prev-month").onclick = () => moveMonth(-1);
$("next-month").onclick = () => moveMonth(1);
$("cam-close").onclick = () => show("calendar");
$("shutter-btn").onclick = () => takePhoto(true);
$("album-btn").onclick = () => takePhoto(false);
$("fail-toggle").onchange = (e) => (state.failNext = e.target.checked);
$("cut-back").onclick = openCamera;
$("res-back").onclick = openCamera;
$("save-btn").onclick = saveSticker;
$("kcal-cancel").onclick = () => ($("kcal-alert").hidden = true);
$("kcal-ok").onclick = saveKcal;
$("kcal-input").onkeydown = (e) => e.key === "Enter" && saveKcal();
$("day-sheet").onclick = (e) => e.target.id === "day-sheet" && ($("day-sheet").hidden = true);

seedHistory();
renderCalendar();
