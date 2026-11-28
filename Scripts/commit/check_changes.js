"use strict";

const GIT_FILE_MODES = new Set(["100644", "100755", "120000", "160000"]);
const PLAIN_EXTENSIONS = new Set(
  ("md yml yaml json txt desktop png svg jpg jpeg gif ico webp xpm patch diff " +
    "c h cpp cc hpp conf cfg ini toml xml html css csv tsv service rules list " +
    "gpg asc key pem crt lock example").split(" "),
);
const PLAIN_NAMES = new Set([
  ".gitignore", ".gitattributes", ".editorconfig", ".dockerignore",
  "LICENSE", "NOTICE", "COPYING", "README", "Makefile",
]);

function isRepoPath(path) {
  return typeof path === "string" && !path.includes("\0") &&
    path.split("/").every(part => part && part !== "." && part !== "..");
}

function snapshotFiles(snapshot, label) {
  if (snapshot?.truncated !== false || !Array.isArray(snapshot.tree)) {
    throw new Error(label + "缺少完整 Git 文件树。");
  }

  const files = new Map();
  const seen = new Set();
  for (const entry of snapshot.tree) {
    if (!isRepoPath(entry?.path) || seen.has(entry.path) ||
        typeof entry.sha !== "string" || !/^(?:[a-f0-9]{40}|[a-f0-9]{64})$/.test(entry.sha)) {
      throw new Error(label + "的 Git 文件树含无效或重复条目。");
    }
    seen.add(entry.path);
    if (entry.mode === "040000") {
      continue;
    }
    if (!GIT_FILE_MODES.has(entry.mode)) {
      throw new Error(label + "含无法识别的 Git 模式，路径 " + JSON.stringify(entry.path) + "。");
    }
    files.set(entry.path, entry);
  }
  return files;
}

function expectedMode(path) {
  // 固定模式与同目录的 check_file_modes.sh 一致。
  const name = path.split("/").pop();
  const extension = name.slice(name.lastIndexOf(".") + 1).toLowerCase();
  if (name.toLowerCase().endsWith(".sh")) {
    return "100755";
  }
  if (PLAIN_NAMES.has(name) || (name.includes(".") && PLAIN_EXTENSIONS.has(extension))) {
    return "100644";
  }
  return undefined;
}

function checkChanges(input) {
  try {
    const { base, head, expectedPaths } = input ?? {};
    const before = snapshotFiles(base, "基准");
    const after = snapshotFiles(head, "目标");
    let expected;
    if (expectedPaths !== undefined) {
      if (!Array.isArray(expectedPaths) || !expectedPaths.every(isRepoPath)) {
        throw new Error("范围清单须使用完整的仓库相对路径。");
      }
      expected = new Set(expectedPaths);
      if (expected.size !== expectedPaths.length) {
        throw new Error("范围清单含重复路径。");
      }
    }

    const changes = [];
    const problems = [];
    for (const path of [...new Set([...before.keys(), ...after.keys()])].sort()) {
      const oldEntry = before.get(path);
      const entry = after.get(path);
      if (oldEntry?.sha !== entry?.sha || oldEntry?.mode !== entry?.mode) {
        const status = oldEntry ? (entry ? "修改" : "删除") : "新增";
        changes.push({ path, status, beforeMode: oldEntry?.mode, afterMode: entry?.mode });
        if (expected && !expected.delete(path)) {
          problems.push("范围外改动 " + JSON.stringify(path));
        }
      }

      if (entry?.mode === "100644" || entry?.mode === "100755") {
        const mode = expectedMode(path);
        if (mode && entry.mode !== mode) {
          problems.push("Git 模式 " + JSON.stringify(path) + " 为 " + entry.mode + "，应为 " + mode);
        }
      }
    }
    for (const path of [...(expected ?? [])].sort()) {
      problems.push("清单路径无改动 " + JSON.stringify(path));
    }

    return { status: problems.length ? "fail" : "pass", changes, problems, scopeChecked: Boolean(expected) };
  } catch (error) {
    return { status: "incomplete", changes: [], problems: [error.message], scopeChecked: false };
  }
}

function formatCheckResult(result) {
  if (result.status === "incomplete") {
    return "检查未完成：" + result.problems.join("\n");
  }

  const summary = (result.status === "pass" ? "通过" : "失败") + "，" +
    result.changes.length + " 个路径有改动。已核对目标全树的固定 Git 模式。" +
    (result.scopeChecked ? "已核对范围清单。" : "未提供范围清单。");
  const changes = result.changes.map(({ status, path, beforeMode, afterMode }) =>
    status + " " + JSON.stringify(path) + " (" + (beforeMode ?? "-") + " -> " + (afterMode ?? "-") + ")",
  );
  return [summary, ...changes, ...result.problems].join("\n");
}

function nulFields(output) {
  const fields = output.split("\0");
  if (fields.pop() !== "") {
    throw new Error("Git 输出缺少记录结束符。");
  }
  return fields;
}

function gitSnapshot(git, commit) {
  const lines = nulFields(git(["ls-tree", "-r", "-z", "--full-tree", commit]));
  const tree = lines.map(line => {
    const tab = line.indexOf("\t");
    if (tab < 0) {
      throw new Error("无法读取完整的 Git 文件树。");
    }
    const [mode, , sha] = line.slice(0, tab).split(" ");
    return { mode, sha, path: line.slice(tab + 1) };
  });
  return { truncated: false, tree };
}

function stagedSnapshot(git, commit, base) {
  const fields = nulFields(git([
    "diff", "--cached", "--raw", "-z", "--no-abbrev", "--no-renames", "--no-ext-diff",
    "--ignore-submodules=none", "--no-relative", "--ita-invisible-in-index", commit, "--",
  ]));
  const files = new Map(base.tree.map(entry => [entry.path, entry]));

  // 禁用重命名识别后，每对 NUL 分隔字段是变更元数据和一个完整路径。
  for (let i = 0; i < fields.length; i += 2) {
    const [, mode, , sha, status] = fields[i].split(" ");
    const path = fields[i + 1];
    if (status === "U") {
      throw new Error("索引存在未合并路径 " + JSON.stringify(path) + "。");
    }
    if (!isRepoPath(path) || !["A", "D", "M", "T"].includes(status)) {
      throw new Error("无法读取完整的暂存差异。");
    }
    if (status === "D") {
      files.delete(path);
    } else {
      files.set(path, { mode, sha, path });
    }
  }
  return { truncated: false, tree: [...files.values()] };
}

const USAGE = [
  "用法：node Scripts/commit/check_changes.js --staged [-- <路径> ...]",
  "      node Scripts/commit/check_changes.js --commits <基准> <目标> [-- <路径> ...]",
].join("\n");

function runCli(args) {
  if (args.length === 1 && ["--help", "-h"].includes(args[0])) {
    console.log(USAGE);
    return 0;
  }

  const separator = args.indexOf("--");
  const command = separator < 0 ? args : args.slice(0, separator);
  const expectedPaths = separator < 0 ? undefined : args.slice(separator + 1);
  const staged = command[0] === "--staged" && command.length === 1;
  if (!staged && !(command[0] === "--commits" && command.length === 3)) {
    console.error(USAGE);
    return 2;
  }

  const { execFileSync } = require("node:child_process");
  const decoder = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
  const git = gitArgs => decoder.decode(execFileSync("git", ["-c", "core.fsmonitor=false", ...gitArgs], {
    env: { ...process.env, GIT_OPTIONAL_LOCKS: "0", GIT_NO_LAZY_FETCH: "1", GIT_NO_REPLACE_OBJECTS: "1" },
    maxBuffer: 32 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const resolve = ref => git(["rev-parse", "--verify", "--end-of-options", ref + "^{commit}"]).trim();

  try {
    const baseCommit = resolve(staged ? "HEAD" : command[1]);
    const base = gitSnapshot(git, baseCommit);
    const head = staged ? stagedSnapshot(git, baseCommit, base) : gitSnapshot(git, resolve(command[2]));
    const result = checkChanges({ base, head, expectedPaths });
    console.log(formatCheckResult(result));
    return { pass: 0, fail: 1, incomplete: 2 }[result.status];
  } catch (error) {
    const reason = error.stderr?.toString().trim() || error.message;
    console.error("检查未完成：" + reason);
    return 2;
  }
}

if (typeof require === "function" && typeof module !== "undefined" && require.main === module) {
  process.exitCode = runCli(process.argv.slice(2));
}
