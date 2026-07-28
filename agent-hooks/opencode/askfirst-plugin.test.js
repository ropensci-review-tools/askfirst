// Unit tests for askfirst-plugin.js's pure logic, exercised only through
// the real AskfirstPlugin export (invoked exactly the way opencode itself
// invokes it) -- never by exporting internal helpers directly, since
// opencode's plugin loader tries to invoke every exported binding as if
// it were a Plugin function, and a mismatched extra export was confirmed
// live (this stage's tasks.md, T017-9) to hang plugin loading entirely.
import { test, expect, beforeEach, afterEach } from "bun:test";
import fs from "fs";
import path from "path";
import os from "os";
import { AskfirstPlugin } from "./askfirst-plugin.js";

let projectDir;
let stateDir;

function mangle(p) {
  return p.replace(/^\//, "").replace(/\//g, "_");
}

beforeEach(() => {
  projectDir = fs.mkdtempSync(path.join(os.tmpdir(), "askfirst-plugin-test-"));
  stateDir = path.join(os.tmpdir(), "askfirst", mangle(projectDir));
});

afterEach(() => {
  fs.rmSync(projectDir, { recursive: true, force: true });
  fs.rmSync(stateDir, { recursive: true, force: true });
});

test("askfirstMangleTermPath matches the shared behavioral-contract fixture", async () => {
  // Shared with bindings/r/tests/testthat/test-log.R's
  // askfirst_mangle_path() fixture test -- bash/JS/R can't literally
  // share the mangling function's code, so all three are checked against
  // the same input/output pairs here (stage 018, Design Goal 4). Verified
  // indirectly, via the real AskfirstPlugin export: for each fixture
  // pair, a marker file is placed at the FIXTURE's own expected path (not
  // this test file's separate `mangle()` setup helper), and a real hook
  // call must find it -- so this test would catch drift between
  // askfirstMangleTermPath() and the fixture even if this file's own
  // `mangle()` helper (used only for other tests' setup) happened to
  // drift too.
  const fixturePath = path.join(import.meta.dir, "..", "askfirst-state-dir-fixture.txt");
  const fixtureLines = fs
    .readFileSync(fixturePath, "utf8")
    .split("\n")
    .filter((l) => l.length > 0);

  for (const line of fixtureLines) {
    const [input, expected = ""] = line.split("\t");
    if (expected === "") {
      // The "/" -> "" edge case mangles to the shared state-root itself
      // (${TMPDIR}/askfirst), not a private per-fixture directory --
      // recursively deleting that in cleanup would be destructive to
      // shared test infrastructure. Covered directly (and safely, with
      // no filesystem side effects) by test-log.R's fixture test instead.
      continue;
    }
    const fixtureStateDir = path.join(os.tmpdir(), "askfirst", expected);
    fs.mkdirSync(fixtureStateDir, { recursive: true });
    fs.writeFileSync(path.join(fixtureStateDir, "log"), "fixture marker\n");

    try {
      const hooks = await AskfirstPlugin({ directory: input });
      const output = { tool: "irrelevant", output: "real output", title: "t", metadata: {} };
      await hooks["tool.execute.after"]({ tool: "irrelevant" }, output);
      expect(output.output).toContain("fixture marker");
    } finally {
      fs.rmSync(fixtureStateDir, { recursive: true, force: true });
    }
  }
});

test("state dir mangling matches the R/bash scheme", () => {
  // Indirect: the plugin computes its own state dir internally from
  // `directory`; we confirm it lands exactly where the R/bash mangling
  // scheme would, by writing a marker file there ourselves and letting
  // a hook find it.
  fs.mkdirSync(stateDir, { recursive: true });
  fs.writeFileSync(path.join(stateDir, "log"), "hello from log\n");

  return AskfirstPlugin({ directory: projectDir }).then(async (hooks) => {
    const output = { tool: "irrelevant", output: "real tool output", title: "t", metadata: {} };
    await hooks["tool.execute.after"]({ tool: "irrelevant" }, output);
    expect(output.output).toContain("hello from log");
    expect(output.output).toContain("real tool output");
    expect(fs.existsSync(path.join(stateDir, "log"))).toBe(false);
  });
});

test("experimental.chat.system.transform pushes the askfirst-context block", async () => {
  const hooks = await AskfirstPlugin({ directory: projectDir });
  const output = { system: ["existing prompt content"] };
  await hooks["experimental.chat.system.transform"]({ model: {} }, output);
  expect(output.system.length).toBe(2);
  expect(output.system[1]).toContain("<askfirst-context>");
  expect(output.system[1]).toContain("askfirst_check_scenarios");
});

test("experimental.chat.system.transform is safe to call multiple times per turn", async () => {
  const hooks = await AskfirstPlugin({ directory: projectDir });
  const output = { system: [] };
  await hooks["experimental.chat.system.transform"]({ model: {} }, output);
  await hooks["experimental.chat.system.transform"]({ model: {} }, output);
  expect(output.system.length).toBe(2);
  expect(output.system[0]).toBe(output.system[1]);
});

test("tool.execute.after flushes the log without a notice marker present", async () => {
  fs.mkdirSync(stateDir, { recursive: true });
  fs.writeFileSync(path.join(stateDir, "log"), "notice text");

  const hooks = await AskfirstPlugin({ directory: projectDir });
  const output = { tool: "edit", output: "diff output", title: "t", metadata: {} };
  await hooks["tool.execute.after"]({ tool: "edit" }, output);

  expect(output.output).toContain("[askfirst-annotation:]");
  expect(output.output).toContain("notice text");
  expect(output.output).not.toContain("[askfirst-unresolved-notice-reminder:]");
});

test("tool.execute.after escalates the reminder only for file-modifying tools", async () => {
  const noticeDir = path.join(stateDir, "unresolved-notice");
  fs.mkdirSync(noticeDir, { recursive: true });
  fs.writeFileSync(path.join(noticeDir, "dodgr.txt"), "dodgr notice text");

  const hooks = await AskfirstPlugin({ directory: projectDir });

  const readOutput = { tool: "read", output: "file contents", title: "t", metadata: {} };
  await hooks["tool.execute.after"]({ tool: "read" }, readOutput);
  expect(readOutput.output).toBe("file contents");
  expect(
    fs.existsSync(path.join(stateDir, "unresolved-notice-count", "dodgr.txt"))
  ).toBe(false);

  const editOutput = { tool: "edit", output: "diff", title: "t", metadata: {} };
  await hooks["tool.execute.after"]({ tool: "edit" }, editOutput);
  expect(editOutput.output).toContain("[askfirst-unresolved-notice-reminder:]");
  expect(editOutput.output).toContain("dodgr");
  expect(editOutput.output).not.toContain("REPEATED");
});

for (const tool of ["edit", "write", "apply_patch"]) {
  test(`tool.execute.after recognizes "${tool}" as file-modifying`, async () => {
    const noticeDir = path.join(stateDir, "unresolved-notice");
    fs.mkdirSync(noticeDir, { recursive: true });
    fs.writeFileSync(path.join(noticeDir, "dodgr.txt"), "dodgr notice text");

    const hooks = await AskfirstPlugin({ directory: projectDir });
    const output = { tool, output: "result", title: "t", metadata: {} };
    await hooks["tool.execute.after"]({ tool }, output);
    expect(output.output).toContain("[askfirst-unresolved-notice-reminder:]");
  });
}

test("escalation reaches the REPEATED level-2 wording on the 3rd occurrence", async () => {
  const noticeDir = path.join(stateDir, "unresolved-notice");
  fs.mkdirSync(noticeDir, { recursive: true });
  fs.writeFileSync(path.join(noticeDir, "dodgr.txt"), "dodgr notice text");

  const hooks = await AskfirstPlugin({ directory: projectDir });

  let output;
  for (let i = 1; i <= 3; i++) {
    output = { tool: "edit", output: "result", title: "t", metadata: {} };
    await hooks["tool.execute.after"]({ tool: "edit" }, output);
    if (i < 3) {
      expect(output.output).not.toContain("REPEATED");
    }
  }
  expect(output.output).toContain("REPEATED reminder (3x)");
  expect(
    fs.readFileSync(path.join(stateDir, "unresolved-notice-count", "dodgr.txt"), "utf8")
  ).toBe("3");
});

test("tool.execute.before throws while a pending sentinel exists", async () => {
  const pendingDir = path.join(stateDir, "pending");
  fs.mkdirSync(pendingDir, { recursive: true });
  fs.writeFileSync(path.join(pendingDir, "dodgr-capability_gap.txt"), "STOP AND ASK message");

  const hooks = await AskfirstPlugin({ directory: projectDir });
  await expect(
    hooks["tool.execute.before"]({ tool: "read" }, { args: {} })
  ).rejects.toThrow("STOP AND ASK message");
});

test("tool.execute.before does not throw when no pending sentinel exists", async () => {
  const hooks = await AskfirstPlugin({ directory: projectDir });
  await expect(
    hooks["tool.execute.before"]({ tool: "read" }, { args: {} })
  ).resolves.toBeUndefined();
});

test('"chat.message" clears pending/ but leaves unresolved-notice/ untouched', async () => {
  const pendingDir = path.join(stateDir, "pending");
  const noticeDir = path.join(stateDir, "unresolved-notice");
  fs.mkdirSync(pendingDir, { recursive: true });
  fs.mkdirSync(noticeDir, { recursive: true });
  fs.writeFileSync(path.join(pendingDir, "dodgr-capability_gap.txt"), "STOP");
  fs.writeFileSync(path.join(noticeDir, "dodgr.txt"), "notice");

  const hooks = await AskfirstPlugin({ directory: projectDir });
  await hooks["chat.message"]({ sessionID: "s1" }, { message: {}, parts: [] });

  expect(fs.existsSync(pendingDir)).toBe(false);
  expect(fs.existsSync(path.join(noticeDir, "dodgr.txt"))).toBe(true);
});
