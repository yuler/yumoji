import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { isReleasePath, resolveReleasePlan } from "./resolve-release.mjs";

function createRepo() {
  const dir = mkdtempSync(join(tmpdir(), "yumoji-release-test-"));
  const run = (...args) =>
    execFileSync("git", args, {
      cwd: dir,
      encoding: "utf8",
      env: {
        ...process.env,
        GIT_AUTHOR_NAME: "Test",
        GIT_AUTHOR_EMAIL: "test@example.com",
        GIT_COMMITTER_NAME: "Test",
        GIT_COMMITTER_EMAIL: "test@example.com",
      },
    }).trim();

  run("init", "-b", "main");

  const commitFile = (relPath, content, message) => {
    const full = join(dir, relPath);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, content);
    run("add", relPath);
    run("commit", "-m", message);
    return run("rev-parse", "HEAD");
  };

  return {
    dir,
    run,
    commitFile,
    cleanup: () => rmSync(dir, { recursive: true, force: true }),
  };
}

test("isReleasePath matches iOS app and release script paths only", () => {
  assert.equal(isReleasePath("ios/Yumoji/App.swift"), true);
  assert.equal(isReleasePath("ios/project.yml"), true);
  assert.equal(isReleasePath("scripts/ios-xcodegen.sh"), true);
  assert.equal(isReleasePath("scripts/lib.sh"), true);
  assert.equal(isReleasePath("scripts/resolve-version.sh"), true);
  assert.equal(isReleasePath(".github/workflows/ios-release.yml"), true);

  assert.equal(isReleasePath("README.md"), false);
  assert.equal(isReleasePath("docs/feasibility-and-plan.md"), false);
  assert.equal(isReleasePath("prototypes/core-loop/app.js"), false);
  assert.equal(isReleasePath("scripts/setup-testflight.sh"), false);
});

test("auto release starts at v0.0.1 when no tags exist and ios/ changes", () => {
  const repo = createRepo();
  try {
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v1\n", "✨ [ios] Initial app");

    const plan = resolveReleasePlan({ cwd: repo.dir, eventName: "workflow_run" });
    assert.equal(plan.skip, false);
    assert.equal(plan.version, "0.0.1");
    assert.equal(plan.tag, "v0.0.1");
    assert.equal(plan.createTag, true);
    assert.equal(plan.uploadTestflight, true);
    assert.equal(plan.bump, "patch");
  } finally {
    repo.cleanup();
  }
});

test("auto release bumps patch on ios/ or release script change", () => {
  const repo = createRepo();
  try {
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v1\n", "init");
    repo.run("tag", "v0.1.0");
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v2\n", "🐛 [ios] Fix swipe card");

    const plan = resolveReleasePlan({ cwd: repo.dir, eventName: "workflow_run" });
    assert.equal(plan.skip, false);
    assert.equal(plan.version, "0.1.1");
    assert.equal(plan.tag, "v0.1.1");
    assert.equal(plan.createTag, true);
    assert.equal(plan.uploadTestflight, true);
    assert.equal(plan.bump, "patch");
  } finally {
    repo.cleanup();
  }
});

test("auto release skips docs and prototype-only commits", () => {
  const repo = createRepo();
  try {
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v1\n", "init");
    repo.run("tag", "v0.1.0");
    repo.commitFile("README.md", "# Yumoji\n", "📝 [docs] Update README");
    repo.commitFile("prototypes/core-loop/app.js", "// prototype\n", "🎨 [proto] Tweak card");

    const plan = resolveReleasePlan({ cwd: repo.dir, eventName: "workflow_run" });
    assert.equal(plan.skip, true);
    assert.equal(plan.uploadTestflight, false);
  } finally {
    repo.cleanup();
  }
});

test("auto release honors [major] > [minor] > patch and [skip release]", () => {
  const repo = createRepo();
  try {
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v1\n", "init");
    repo.run("tag", "v0.1.0");
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v2\n", "✨ [ios] Add daily deck [minor]");
    repo.commitFile("scripts/lib.sh", "# v2\n", "💥 [ios] Breaking build change [major]");
    repo.commitFile("README.md", "docs\n", "📝 [docs] Update docs");

    const plan = resolveReleasePlan({ cwd: repo.dir, eventName: "workflow_run" });
    assert.equal(plan.skip, false);
    assert.equal(plan.version, "1.0.0");
    assert.equal(plan.bump, "major");

    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v3\n", "🔧 [ios] Chore [skip release]");
    const skipped = resolveReleasePlan({ cwd: repo.dir, eventName: "workflow_run" });
    assert.equal(skipped.skip, true);
  } finally {
    repo.cleanup();
  }
});

test("auto release skips stale commit that is an ancestor of highest tag", () => {
  const repo = createRepo();
  try {
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v1\n", "init");
    repo.run("tag", "v0.1.0");
    const c1 = repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v2\n", "fix 1");
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v3\n", "fix 2");
    repo.run("tag", "v0.1.1");

    const plan = resolveReleasePlan({
      cwd: repo.dir,
      eventName: "workflow_run",
      targetSha: c1,
    });
    assert.equal(plan.skip, true);
    assert.match(plan.reason, /ancestor of v0\.1\.1/);
  } finally {
    repo.cleanup();
  }
});

test("manual workflow_dispatch supports bump, explicit version, and testflight modes", () => {
  const repo = createRepo();
  try {
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v1\n", "init");
    repo.run("tag", "v0.1.0");

    const minorPlan = resolveReleasePlan({
      cwd: repo.dir,
      eventName: "workflow_dispatch",
      inputBump: "minor",
      inputTestflight: "always",
    });
    assert.equal(minorPlan.skip, false);
    assert.equal(minorPlan.version, "0.2.0");
    assert.equal(minorPlan.createTag, true);
    assert.equal(minorPlan.uploadTestflight, true);

    const skipPlan = resolveReleasePlan({
      cwd: repo.dir,
      eventName: "workflow_dispatch",
      inputVersion: "1.0.0",
      inputTestflight: "skip",
    });
    assert.equal(skipPlan.skip, false);
    assert.equal(skipPlan.version, "1.0.0");
    assert.equal(skipPlan.uploadTestflight, false);

    const boolFalsePlan = resolveReleasePlan({
      cwd: repo.dir,
      eventName: "workflow_dispatch",
      inputBump: "patch",
      inputTestflight: "false",
    });
    assert.equal(boolFalsePlan.skip, false);
    assert.equal(boolFalsePlan.version, "0.1.1");
    assert.equal(boolFalsePlan.uploadTestflight, false);
  } finally {
    repo.cleanup();
  }
});

test("manual tag push reuses existing tag without re-creating it", () => {
  const repo = createRepo();
  try {
    repo.commitFile("ios/Yumoji/YumojiApp.swift", "// v1\n", "init");
    repo.run("tag", "v0.2.0");

    const plan = resolveReleasePlan({
      cwd: repo.dir,
      eventName: "push",
      refName: "v0.2.0",
    });
    assert.equal(plan.skip, false);
    assert.equal(plan.version, "0.2.0");
    assert.equal(plan.tag, "v0.2.0");
    assert.equal(plan.createTag, false);
    assert.equal(plan.uploadTestflight, true);
  } finally {
    repo.cleanup();
  }
});
