import { describe, test, expect } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

import { parseJUnitXMLContent, parseJUnitXMLContentExamples } from "./parser";

describe("sanitize-junit-xml.ts", () => {
  test("produces minimal XML that preserves testcase time/name/classname parsing", () => {
    const tempDir = mkdtempSync(join(tmpdir(), "junit-sanitize-test-"));

    try {
      const inputXml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="2" failures="1" errors="0" time="999">
  <testsuite name="spec/arguments_spec.sh" tests="2" failures="1" errors="0" skipped="0" time="12.345">
    <testcase classname="spec/arguments_spec.sh" name="a &quot;quoted&quot; test" time="0.234">
      <failure message="nope"><![CDATA[big stacktrace]]></failure>
    </testcase>
    <testcase classname="spec/arguments_spec.sh" name="another test" time="0.500"></testcase>
  </testsuite>
</testsuites>`;

      const inputPath = join(tempDir, "input.xml");
      const outputPath = join(tempDir, "sanitized.xml");
      writeFileSync(inputPath, inputXml);

      const beforeFile = parseJUnitXMLContent(inputXml);
      const beforeExamples = parseJUnitXMLContentExamples(inputXml);

      const projectRoot = join(import.meta.dir, "../../../../");
      const result = Bun.spawnSync(["bun", ".github/scripts/junit/src/sanitize-junit-xml.ts", outputPath, inputPath], {
        cwd: projectRoot,
        stdout: "pipe",
        stderr: "pipe",
      });

      expect(result.exitCode).toBe(0);

      const sanitized = readFileSync(outputPath, "utf-8");
      expect(sanitized).toContain("<testsuites>");
      expect(sanitized).toContain("<testcase ");
      expect(sanitized).not.toContain("<failure");
      expect(sanitized).not.toContain("<testsuite ");

      const afterFile = parseJUnitXMLContent(sanitized);
      const afterExamples = parseJUnitXMLContentExamples(sanitized);

      expect(afterFile).toEqual(beforeFile);
      expect(afterExamples).toHaveLength(beforeExamples.length);

      const sizes = { before: inputXml.length, after: sanitized.length };
      expect(sizes.after).toBeLessThan(sizes.before);
    } finally {
      rmSync(tempDir, { recursive: true, force: true });
    }
  });
});
