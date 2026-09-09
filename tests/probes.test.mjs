import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const service = readFileSync(new URL("../Service.qml", import.meta.url), "utf8");
const panel = readFileSync(new URL("../Panel.qml", import.meta.url), "utf8");
const manifest = JSON.parse(readFileSync(new URL("../manifest.json", import.meta.url), "utf8"));

// Execute the actual QML handler bodies, not a duplicate parser. Runtime
// admission and live Process delivery are separate integration checks.
function handler(id) {
  const block = service.split(`    id: ${id}\n`)[1]?.split("\n  }\n")[0];
  assert.ok(block, `missing ${id}`);
  const body = block.match(/onExited: function\(exitCode\) \{([\s\S]*)\n    \}/)?.[1];
  assert.ok(body, `missing ${id} exit handler`);
  return (root, exitCode, stdout = "", stderr = "") => {
    vm.runInNewContext(body, {
      root, exitCode, updatesOut: { text: stdout }, updatesErr: { text: stderr },
      orphansOut: { text: stdout }, orphansErr: { text: stderr }
    }, { timeout: 100 });
  };
}

assert.match(service, /property int pendingUpdates: -1/);
assert.match(service, /property int orphanCount: -1/);
assert.match(service, /command: \["\/bootstrap", "--exec", "checkupdates"\]/);
assert.match(service, /command: \["\/bootstrap", "--exec", "pacman", "-Qdtq"\]/);
assert.deepEqual(manifest.sandbox.requests.exec.checkupdates, {
  executable: "/usr/bin/checkupdates", tree: { end: "pending-updates" }
});
assert.deepEqual(manifest.sandbox.requests.exec.pacman, {
  executable: "/usr/bin/pacman",
  tree: { next: [{ arg: { kind: "exact", value: "-Qdtq" }, then: { end: "orphan-packages" } }] }
});

const updates = handler("updatesProc");
const orphans = handler("orphansProc");
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
updates(root, 2);
orphans(root, 1);
assert.deepEqual(root, { pendingUpdates: 0, orphanCount: 0 });
updates(root, 0, " \n");
orphans(root, 0, " \n");
assert.deepEqual(root, { pendingUpdates: 0, orphanCount: 0 });
assert.match(panel, /petService.pendingUpdates < 0 \? "update status unavailable"/);
assert.match(panel, /petService.orphanCount < 0 \? "package status unavailable/);
console.log("PASS: exact package-query requests, counts, unknown and retained failure state");
