// 页面流程对应 ContentView / HomeView / ResultView，状态机对应 StickerSession.swift。
const $ = (id) => document.getElementById(id);

const session = {
  isActive: false,
  cutout: "working", // "working" | "ready" | "noSubject" | { failed: message }
  analysis: "loading", // "loading" | { loaded: FoodAnalysis } | "failed"
  sticker: null,
  subjectLongSide: 0,
  style: { ...DEFAULT_STYLE },
  simulateAnalysisFailure: false,
  lifted: null,
  generation: 0,
  timers: [],
};

const control = (name) => document.querySelector(`input[name="${name}"]:checked`).value;
const cameraAvailable = () => $("ctl-camera").checked;

function later(fn, ms) {
  const token = session.generation;
  session.timers.push(setTimeout(() => token === session.generation && fn(), ms));
}

/* StickerSession */
function start(photo) {
  reset();
  session.isActive = true;
  render();
  // PhotoLoader 解码
  later(() => {
    if (control("cutout") === "unreadable") {
      session.cutout = { failed: "这张照片读不出来" };
      return render();
    }
    startAnalysis();
    // VisionSubjectLifter 抠图，和识别同时进行
    later(() => {
      if (control("cutout") === "noSubject") {
        clearTimeout(session.analysisTimer);
        session.cutout = "noSubject";
        return render();
      }
      session.lifted = renderPhoto(photo);
      const b = session.lifted.bounds;
      session.subjectLongSide = Math.max(b.width, b.height);
      renderSticker();
    }, 900);
  }, 250);
}

function reset() {
  session.timers.forEach(clearTimeout);
  session.timers = [];
  clearTimeout(session.analysisTimer);
  session.generation += 1;
  session.lifted = null;
  session.sticker = null;
  session.subjectLongSide = 0;
  session.cutout = "working";
  session.analysis = "loading";
  session.isActive = false;
  render();
}

function startAnalysis() {
  clearTimeout(session.analysisTimer);
  if (!session.isActive || session.cutout === "noSubject" || session.cutout.failed) return;
  session.analysis = "loading";
  render();
  const shouldFail = session.simulateAnalysisFailure || control("analysis") === "fail";
  const token = session.generation;
  session.analysisTimer = setTimeout(() => {
    if (token !== session.generation) return;
    if (shouldFail) session.analysis = "failed";
    else if (control("analysis") === "notFood") session.analysis = { loaded: NOT_FOOD };
    else session.analysis = { loaded: MOCK_SAMPLES[Math.floor(Math.random() * MOCK_SAMPLES.length)] };
    render();
  }, MOCK_DELAY);
}

let renderQueued = false;
function renderSticker() {
  if (renderQueued) return;
  renderQueued = true;
  requestAnimationFrame(() => {
    renderQueued = false;
    if (!session.lifted) return;
    const out = makeSticker(session.lifted, session.style);
    if (out) {
      session.sticker = out;
      session.cutout = "ready";
    } else if (!session.sticker) {
      session.cutout = { failed: "贴纸合成失败" };
    }
    render();
  });
}

/* 渲染 */
function render() {
  $("home").classList.toggle("active", !session.isActive);
  $("result").classList.toggle("active", session.isActive);
  const camOk = cameraAvailable();
  $("camera-btn").disabled = !camOk;
  $("no-camera").hidden = camOk;
  if (!session.isActive) return;

  renderStage();
  const showsAnalysis = session.cutout === "working" || session.cutout === "ready";
  $("analysis").hidden = !showsAnalysis;
  if (showsAnalysis) renderAnalysis();
  $("tuning").hidden = session.cutout !== "ready";
  if (session.cutout === "ready") renderTuning();
}

const spinner = (text) => `<div class="progress"><i class="spinner"></i><span>${text}</span></div>`;

function renderStage() {
  const stage = $("stage");
  const c = session.cutout;
  const key = typeof c === "string" ? c : "failed";
  if (key === "ready") {
    if (stage.dataset.state !== "ready") {
      stage.innerHTML = "";
      const img = document.createElement("img");
      img.className = "sticker";
      img.alt = "贴纸";
      stage.appendChild(img);
    }
    stage.querySelector("img").src = session.sticker.toDataURL();
  } else if (key === "working") {
    stage.innerHTML = spinner("正在抠图…");
  } else {
    const [title, detail] = key === "noSubject"
      ? ["没找到可以做成贴纸的食物", "换个角度，或者让食物在画面里更突出一些。"]
      : ["抠图没有成功", c.failed];
    stage.innerHTML = `<div class="problem"><p class="problem-emoji">🥲</p><p class="problem-title">${title}</p>
      <p class="problem-detail">${detail}</p><button class="capsule" id="change-btn">换一张照片</button></div>`;
    $("change-btn").onclick = reset;
  }
  stage.dataset.state = key;
}

function renderAnalysis() {
  const card = $("analysis");
  const a = session.analysis;
  if (a === "loading") {
    card.innerHTML = spinner("正在认这是什么好吃的…");
  } else if (a === "failed") {
    card.innerHTML = `<div class="row"><b class="pending">待识别</b>
      <button class="retry" id="retry-btn"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 1 1-2.6-5.9"/><path d="M20 4v5h-5"/></svg>重试</button></div>`;
    $("retry-btn").onclick = startAnalysis;
  } else {
    const f = a.loaded;
    const kcalText = f.isFood && f.kcal != null ? `约 ${Math.max(0, f.kcal)} 千卡` : "";
    card.innerHTML = `<div class="row"><b class="name">${f.name}</b>${kcalText ? `<span class="kcal">${kcalText}</span>` : ""}</div>
      ${f.isFood ? "" : `<p class="warn">这个好像不是吃的</p>`}
      <p class="intro">${[...f.intro].slice(0, INTRO_LIMIT).join("")}</p>`;
  }
}

function renderTuning() {
  const s = session.style;
  document.querySelectorAll(".slider").forEach((el) => {
    const key = el.dataset.key;
    const input = el.querySelector("input");
    [input.min, input.max] = STYLE_RANGES[key];
    if (document.activeElement !== input) input.value = s[key];
    el.querySelector("b").textContent = s[key].toFixed(3);
  });
  const border = s.borderRatio * session.subjectLongSide;
  const lines = [
    `border=${s.borderRatio.toFixed(3)} smooth=${s.edgeSmoothing.toFixed(2)} margin=${s.marginRatio.toFixed(3)}`,
    `主体长边 ${session.subjectLongSide} px · 白边 ${border.toFixed(1)} px`,
  ];
  if (session.sticker) lines.push(`贴纸 ${session.sticker.width} × ${session.sticker.height} px`);
  $("summary").textContent = lines.join("\n");
  $("fail-next").checked = session.simulateAnalysisFailure;
}

/* 系统相机与相册 */
let cameraPhoto = null;
function openCamera() {
  cameraPhoto = PHOTOS[Math.floor(Math.random() * PHOTOS.length)];
  const ctx = $("cam-canvas").getContext("2d");
  ctx.drawImage(renderPhoto(cameraPhoto).canvas, 0, 0);
  setReview(false);
  $("camera").hidden = false;
}
function setReview(on) {
  $("cam-live").hidden = on;
  $("cam-review").hidden = !on;
  $("camera").classList.toggle("review", on);
}

function openPicker() {
  const grid = $("picker-grid");
  if (!grid.children.length) {
    PHOTOS.forEach((p) => {
      const thumb = newCanvas(240, 240);
      thumb.getContext("2d").drawImage(renderPhoto(p).canvas, 0, 0, 240, 240);
      const b = document.createElement("button");
      b.appendChild(thumb);
      b.onclick = () => { $("picker").hidden = true; start(p); };
      grid.appendChild(b);
    });
  }
  $("picker").hidden = false;
}

/* 绑定 */
$("camera-btn").onclick = openCamera;
$("library-btn").onclick = openPicker;
$("cam-cancel").onclick = () => ($("camera").hidden = true);
$("shutter").onclick = () => setReview(true);
$("cam-retake").onclick = () => setReview(false);
$("cam-use").onclick = () => { $("camera").hidden = true; start(cameraPhoto); };
$("picker-cancel").onclick = () => ($("picker").hidden = true);
$("picker").onclick = (e) => e.target.id === "picker" && ($("picker").hidden = true);
$("again-btn").onclick = reset;
$("ctl-camera").onchange = render;

$("tuning-toggle").onclick = () => {
  const body = $("tuning-body");
  body.hidden = !body.hidden;
  $("tuning-toggle").classList.toggle("open", !body.hidden);
};
document.querySelectorAll(".slider input").forEach((input) => {
  input.oninput = () => {
    session.style[input.closest(".slider").dataset.key] = parseFloat(input.value);
    renderTuning();
    renderSticker();
  };
});
$("fail-next").onchange = (e) => (session.simulateAnalysisFailure = e.target.checked);
$("reset-style").onclick = () => { session.style = { ...DEFAULT_STYLE }; renderSticker(); };
$("reanalyze").onclick = startAnalysis;

render();
