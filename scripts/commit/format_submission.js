// 按仓库规则生成提交说明和实机验证记录。

function formatSubmission(input) {
  function checkFields(value, label, allowed) {
    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      throw new Error(`${label} 必须是字段对象。`);
    }
    const unknown = Object.keys(value).find((key) => !allowed.includes(key));
    if (unknown !== undefined) {
      throw new Error(`${label}.${unknown} 是未定义的字段。`);
    }
  }

  function readLine(value, label) {
    if (typeof value !== "string" || value.trim() === "" || /[\u0000-\u001f\u007f\u2028\u2029]/u.test(value)) {
      throw new Error(`${label} 必须填写非空的单行文本。`);
    }
    const line = value.trim();
    if (/^<[^<>]+>$/u.test(line)) {
      throw new Error(`${label} 必须用实际内容替换占位符。`);
    }
    return line;
  }

  function readList(value, label) {
    if (!Array.isArray(value)) {
      throw new Error(`${label} 必须是数组。`);
    }
    return value;
  }

  function readBullet(value, label) {
    const line = readLine(value, label);
    if (/^(?:[-+*]\s|\d+[.)]\s|验证[:：])/u.test(line)) {
      throw new Error(`${label} 只填写正文，列表和验证标签由脚本生成。`);
    }
    return line;
  }

  function readPassedFact(value, label) {
    const line = readBullet(value, label);
    if (/(?:待|未|仍需)(?:用户)?(?:实机)?(?:验证|测试|实测|验收|补测|确认)|验证边界|未覆盖项/u.test(line)) {
      throw new Error(`${label} 只填写已通过的结果或已观察到的事实。`);
    }
    return line;
  }

  function formatCommit(commit) {
    checkFields(commit, "commit", ["title", "changes", "verification", "orderedChanges"]);
    const title = readBullet(commit.title, "commit.title");
    if (!/\p{Script=Han}/u.test(title)) {
      throw new Error("commit.title 必须使用中文标题。");
    }
    const changes = readList(commit.changes, "commit.changes");
    if (changes.length === 0) {
      throw new Error("commit.changes 至少填写一项实际改动。");
    }
    if (commit.orderedChanges !== undefined && typeof commit.orderedChanges !== "boolean") {
      throw new Error("commit.orderedChanges 必须是布尔值。");
    }
    const entries = Array.from(changes, (change, index) => {
      const prefix = commit.orderedChanges ? `${index + 1}.` : "-";
      return `${prefix} ${readBullet(change, `commit.changes[${index}]`)}`;
    });
    const verification = readBullet(commit.verification, "commit.verification");
    const message = [title, "", ...entries, `- 验证：${verification}`].join("\n");
    if (/\[(?:skip\s+ci|ci\s+skip|no\s+ci|skip\s+actions|actions\s+skip)\]|skip-checks\s*:\s*true\b/iu.test(message)) {
      throw new Error("提交说明禁止包含跳过 CI 的标记。");
    }
    return message;
  }

  function readValidationTemplate(template) {
    if (typeof template !== "string") {
      throw new Error("realMachineValidation.template 必须是仓库实机验证模板的完整正文。");
    }
    const blocks = [...template.replace(/\r\n/g, "\n").matchAll(/^```markdown\n([\s\S]*?)\n```[ \t]*$/gm)];
    if (blocks.length !== 1) {
      throw new Error("实机验证模板必须包含唯一的 Markdown 正文模板。");
    }
    const body = blocks[0][1];
    const sections = body.split("\n\n");
    const expectedFields = ["<日期>", "<程序名>", "<实际验证的项目>", "<实际通过的结果>"];
    const fields = body.match(/<[^<>\n]+>/g) ?? [];
    if (sections.length !== 4 || fields.join("\n") !== expectedFields.join("\n")) {
      throw new Error("实机验证模板的结构或占位符已变更，请核对仓库模板。");
    }
    const [heading, dateHeading, conclusion, table] = sections;
    const tableLines = table.split("\n");
    const row = tableLines.at(-1);
    if (heading !== "## 实机验证" || !dateHeading.startsWith("### ") || !dateHeading.includes("<日期>") ||
        !conclusion.includes("<程序名>") || tableLines.length !== 3 ||
        !row.includes("<实际验证的项目>") || !row.includes("<实际通过的结果>")) {
      throw new Error("实机验证模板的标题、结论或实测表结构不匹配。");
    }
    return { heading, dateHeading, conclusion, tableHeader: tableLines.slice(0, -1), row };
  }

  function escapeTableCell(value) {
    // 保留已有转义，并转义其他竖线以维持表格列数。
    return value.replace(/(\\*)\|/g, (_, slashes) => `${slashes}${slashes.length % 2 === 0 ? "\\|" : "|"}`);
  }

  function formatRealMachineValidation(record) {
    checkFields(record, "realMachineValidation", ["template", "date", "application", "version", "results", "observations"]);
    const template = readValidationTemplate(record.template);
    const date = readLine(record.date, "realMachineValidation.date");
    const calendarDate = new Date(`${date}T00:00:00Z`);
    if (!/^\d{4}-\d{2}-\d{2}$/u.test(date) || !Number.isFinite(calendarDate.getTime()) ||
        calendarDate.toISOString().slice(0, 10) !== date) {
      throw new Error("realMachineValidation.date 必须是有效的 YYYY-MM-DD 日期。");
    }
    let application = readLine(record.application, "realMachineValidation.application");
    if (record.version !== undefined) {
      const version = readLine(record.version, "realMachineValidation.version");
      if (version.includes("`")) {
        throw new Error("realMachineValidation.version 直接填写版本，反引号由脚本添加。");
      }
      application += ` \`${version}\``;
    }
    const entryParts = [
      template.dateHeading.replace("<日期>", () => date),
      template.conclusion.replace("<程序名>", () => application)
    ];
    if (record.results !== undefined) {
      const results = readList(record.results, "realMachineValidation.results");
      const rows = Array.from(results, (result, index) => {
        const label = `realMachineValidation.results[${index}]`;
        checkFields(result, label, ["item", "result"]);
        const item = escapeTableCell(readPassedFact(result.item, `${label}.item`));
        const outcome = escapeTableCell(readPassedFact(result.result, `${label}.result`));
        return template.row.replace(/<实际验证的项目>|<实际通过的结果>/g, (field) =>
          field === "<实际验证的项目>" ? item : outcome
        );
      });
      if (rows.length > 0) {
        entryParts.push([...template.tableHeader, ...rows].join("\n"));
      }
    }
    if (record.observations !== undefined) {
      const observations = readList(record.observations, "realMachineValidation.observations");
      if (observations.length > 0) {
        const entries = Array.from(observations, (fact, index) =>
          `- ${readPassedFact(fact, `realMachineValidation.observations[${index}]`)}`
        );
        entryParts.push(["#### 运行观察", "", ...entries].join("\n"));
      }
    }
    const entry = entryParts.join("\n\n");
    return { heading: template.heading, entry, section: `${template.heading}\n\n${entry}` };
  }

  checkFields(input, "input", ["commit", "realMachineValidation"]);
  if (input.commit === undefined && input.realMachineValidation === undefined) {
    throw new Error("至少填写 commit 或 realMachineValidation。");
  }
  const output = {};
  if (input.commit !== undefined) {
    output.commitMessage = formatCommit(input.commit);
  }
  if (input.realMachineValidation !== undefined) {
    output.realMachineValidation = formatRealMachineValidation(input.realMachineValidation);
  }
  return output;
}
