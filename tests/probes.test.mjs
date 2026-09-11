import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const service = readFileSync(new URL("../Service.qml", import.meta.url), "utf8");
const panel = readFileSync(new URL("../Panel.qml", import.meta.url), "utf8");
const manifest = JSON.parse(readFileSync(new URL("../manifest.json", import.meta.url), "utf8"));

// Execute the actual QML handler bodies, not a duplicate parser. Runtime
// admission and live Process delivery are separate integration checks.
function handler(name) {
  const block = service.match(new RegExp("  function " + name + "\\(\\) \\{[\\s\\S]*?\\n  \\}"))?.[0];
  assert.ok(block, `missing ${name}`);
  const body = block.match(/onFinished: result => \{([\s\S]*)\n    \}\}/)?.[1];
  assert.ok(body, `missing ${name} completion handler`);
  return (root, exitCode, stdout = "", stderr = "", status = "completed") => {
    const scope = { ...root, result: { status, exitCode, stdout, stderr }, console: { warn() {} } };
    vm.runInNewContext(`(function () { ${body}\n})()`, scope, { timeout: 100 });
    root.pendingUpdates = scope.pendingUpdates;
    root.orphanCount = scope.orphanCount;
  };
}

assert.match(service, /property int pendingUpdates: -1/);
assert.match(service, /property int orphanCount: -1/);
assert.match(service, /runtime\.exec\("checkupdates", \[\]/);
assert.match(service, /runtime\.exec\("pacman", \["-Qdtq"\]/);
assert.deepEqual(manifest.sandbox.requests.exec.checkupdates, {
  executable: "/usr/bin/checkupdates", tree: { end: "pending-updates" }
});
assert.deepEqual(manifest.sandbox.requests.exec.pacman, {
  executable: "/usr/bin/pacman",
  tree: { next: [{ arg: { kind: "exact", value: "-Qdtq" }, then: { end: "orphan-packages" } }] }
});

const updates = handler("queryUpdates");
const orphans = handler("queryOrphans");
const root = { pendingUpdates: -1, orphanCount: -1 };
updates(root, 1, "", "not admitted");
orphans(root, 1, "", "not admitted");
assert.deepEqual(root, { pendingUpdates: -1, orphanCount: -1 });
updates(root, 0, "one 1 -> 2\ntwo 3 -> 4\n");
orphans(root, 0, "orphan-a\norphan-b\norphan-c\n");
assert.deepEqual(root, { pendingUpdates: 2, orphanCount: 3 });
for (const code of [1, 9, 124]) {
  updates(root, code, "", "offline or timeout");
  orphans(root, code, "", "query failed");
  assert.deepEqual(root, { pendingUpdates: 2, orphanCount: 3 });
}
for (const status of ["denied", "unavailable", "failed", "cancelled"]) {
  updates(root, 0, "", "", status);
  orphans(root, 1, "", "", status);
  assert.deepEqual(root, { pendingUpdates: 2, orphanCount: 3 });
}
updates(root, 0, {base64: "/w=="});
orphans(root, 0, {base64: "/w=="});
assert.deepEqual(root, { pendingUpdates: 2, orphanCount: 3 });
updates(root, 2);
orphans(root, 1);
assert.deepEqual(root, { pendingUpdates: 0, orphanCount: 0 });
updates(root, 0, " \n");
orphans(root, 0, " \n");
assert.deepEqual(root, { pendingUpdates: 0, orphanCount: 0 });
assert.match(panel, /petService.pendingUpdates < 0 \? "update status unavailable"/);
assert.match(panel, /petService.orphanCount < 0 \? "package status unavailable/);
console.log("PASS: exact package-query requests, counts, unknown and retained failure state");
