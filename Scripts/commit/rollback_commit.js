// 预览并按用户确认的范围撤回 main 最新的一笔普通提交。

async function rollbackCommit(input, { fetch, updateRef }) {
  if (!input || !["preview", "apply"].includes(input.action)) {
    throw new Error("action 必须填写 preview 或 apply。");
  }
  const applying = input.action === "apply";
  const request = applying ? input.preview : input;
  if (applying && (input.confirmed !== true || request?.branch !== "main" || !Array.isArray(request.files))) {
    throw new Error("执行撤回必须使用本次预览和用户随后给出的明确同意。");
  }
  if (applying && typeof updateRef !== "function") {
    throw new Error("执行撤回需要支持 expected_sha 的 GitHub 连接器。");
  }

  const repository = request.repository;
  if (typeof repository !== "string" || !/^[a-z0-9][a-z0-9-]*\/(?!\.{1,2}$)[a-z0-9_.-]+$/iu.test(repository)) {
    throw new Error("repository 必须填写完整的所有者与仓库名。");
  }
  const api = `https://api.github.com/repos/${repository}`;

  function readSha(value, label, allowShort = false) {
    const pattern = allowShort ? /^[0-9a-f]{7,40}$/iu : /^[0-9a-f]{40}$/iu;
    if (typeof value !== "string" || !pattern.test(value)) {
      throw new Error(`${label} 的 Git SHA 无效。`);
    }
    return value.toLowerCase();
  }

  function connectorError(result) {
    return result?.structuredContent?.error ?? result?.content?.[0]?.text ?? "连接器未返回有效结果。";
  }

  async function read(path) {
    const result = await fetch({ url: api + path });
    const payload = result?.structuredContent;
    if (result?.isError || payload?.error || typeof payload?.content !== "string") {
      throw new Error(`GitHub 读取 ${path} 失败。${connectorError(result)}`);
    }
    return JSON.parse(payload.content);
  }

  async function readMain() {
    const ref = await read("/git/ref/heads/main");
    if (ref?.ref !== "refs/heads/main" || ref.object?.type !== "commit") {
      throw new Error("GitHub 未返回指向提交的 main 分支引用。");
    }
    return readSha(ref.object.sha, "main 分支头");
  }

  async function readCommit(sha) {
    const commit = await read(`/git/commits/${sha}`);
    if (commit?.sha !== sha || !Array.isArray(commit.parents)) {
      throw new Error(`GitHub 未返回 ${sha} 的完整提交信息。`);
    }
    return commit;
  }

  async function readTreeFiles(sha) {
    const gitTree = await read(`/git/trees/${sha}?recursive=1`);
    if (gitTree?.sha !== sha || gitTree.truncated !== false || !Array.isArray(gitTree.tree)) {
      throw new Error(`无法读取 ${sha} 的完整目录树，撤回已停止。`);
    }
    const typesByMode = { "040000": "tree", "100644": "blob", "100755": "blob", "120000": "blob", "160000": "commit" };
    const files = new Map();
    for (const entry of gitTree.tree) {
      if (typeof entry?.path !== "string" || entry.path === "" ||
          !Object.hasOwn(typesByMode, entry.mode) || typesByMode[entry.mode] !== entry.type) {
        throw new Error(`目录树 ${sha} 包含无效的文件条目。`);
      }
      if (entry.type !== "tree") {
        files.set(entry.path, { mode: entry.mode, sha: readSha(entry.sha, "文件对象") });
      }
    }
    return files;
  }

  const requestedSha = readSha(request.targetSha, "目标提交", !applying);
  const targetSha = await readMain();
  if (!targetSha.startsWith(requestedSha)) {
    throw new Error(`main 当前指向 ${targetSha}，与本次目标 ${requestedSha} 不符，撤回已停止。`);
  }

  const target = await readCommit(targetSha);
  if (target.parents.length !== 1) {
    throw new Error("当前撤回入口仅支持 main 最新且恰有一个父提交的提交。");
  }
  const restoreSha = readSha(target.parents[0]?.sha, "父提交");
  const parent = await readCommit(restoreSha);
  const targetTreeSha = readSha(target.tree?.sha, "目标目录树");
  const restoreTreeSha = readSha(parent.tree?.sha, "恢复目录树");
  const commits = { repository, branch: "main", targetSha, restoreSha, targetTreeSha, restoreTreeSha };

  if (!applying) {
    const files = [];
    if (targetTreeSha !== restoreTreeSha) {
      // 用两棵完整目录树计算从当前状态到恢复点的文件变化。
      const [current, restored] = await Promise.all([readTreeFiles(targetTreeSha), readTreeFiles(restoreTreeSha)]);
      const paths = [...new Set([...current.keys(), ...restored.keys()])].sort();
      for (const path of paths) {
        const before = current.get(path) ?? null;
        const after = restored.get(path) ?? null;
        if (before?.sha !== after?.sha || before?.mode !== after?.mode) {
          files.push({ path, before, after });
        }
      }
    }
    return {
      ...commits,
      subject: target.message?.split("\n", 1)[0] ?? "",
      commitUrl: `https://github.com/${repository}/commit/${targetSha}`,
      files
    };
  }

  if (request.restoreSha !== restoreSha || request.targetTreeSha !== targetTreeSha ||
      request.restoreTreeSha !== restoreTreeSha) {
    throw new Error("远端提交与获准预览不一致，撤回已停止。");
  }
  const latestSha = await readMain();
  if (latestSha !== targetSha) {
    throw new Error(`main 已移动到 ${latestSha}，本次撤回已停止。`);
  }

  let updateError = null;
  try {
    // 仅在远端分支头仍是预览所列目标时，将 main 移回唯一父提交。
    const result = await updateRef({
      repository_full_name: repository,
      branch_name: "main",
      sha: restoreSha,
      expected_sha: targetSha,
      force: true
    });
    if (!result || result.isError || result.structuredContent?.error) {
      updateError = connectorError(result);
    }
  } catch (error) {
    updateError = error instanceof Error ? error.message : String(error);
  }

  try {
    // 核对实际分支头，再按该提交读取最近历史和最终目录树 SHA。
    const actualSha = await readMain();
    if (actualSha !== restoreSha) {
      throw new Error(`main 当前指向 ${actualSha}，预期恢复点为 ${restoreSha}。`);
    }
    const history = await read(`/commits?sha=${actualSha}&per_page=2`);
    if (!Array.isArray(history) || history[0]?.sha !== restoreSha || history[0]?.commit?.tree?.sha !== restoreTreeSha ||
        history.some((commit) => commit.sha === targetSha)) {
      throw new Error("最近提交历史或最终目录树与预览不一致。");
    }
  } catch (error) {
    const connection = updateError ? ` 连接器更新响应为 ${updateError}` : "";
    throw new Error(`远端撤回复核未通过。${error.message}${connection}`);
  }

  return {
    ...commits,
    status: updateError ? "verified_after_update_error" : "applied",
    updateError
  };
}
