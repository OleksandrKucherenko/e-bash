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

  test("correctly distinguishes name from classname attribute (regression test)", () => {
    const tempDir = mkdtempSync(join(tmpdir(), "junit-sanitize-regression-"));

    try {
      // This XML mimics real ShellSpec output where name contains the actual test description
      // and classname contains the spec file path. The bug was that the 'name' regex
      // would match 'classname' because 'name' is a substring of 'classname'.
      const inputXml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="1" time="0.83" errors="0" failures="0" name="e-bash">
  <testsuite id="0" tests="1" errors="0" failures="0" skipped="0" name="spec/installation_spec.sh">
    <testcase time="1.234" classname="spec/installation_spec.sh" name="bin/install.e-bash.sh / Script Name Detection / should show script path">
      <system-out><![CDATA[output here]]></system-out>
    </testcase>
  </testsuite>
</testsuites>`;

      const inputPath = join(tempDir, "input.xml");
      const outputPath = join(tempDir, "sanitized.xml");
      writeFileSync(inputPath, inputXml);

      const projectRoot = join(import.meta.dir, "../../../../");
      const result = Bun.spawnSync(["bun", ".github/scripts/junit/src/sanitize-junit-xml.ts", outputPath, inputPath], {
        cwd: projectRoot,
        stdout: "pipe",
        stderr: "pipe",
      });

      expect(result.exitCode).toBe(0);

      const sanitized = readFileSync(outputPath, "utf-8");

      // The key assertion: name should be the test description, NOT the file path
      expect(sanitized).toContain('name="bin/install.e-bash.sh / Script Name Detection / should show script path"');
      expect(sanitized).toContain('classname="spec/installation_spec.sh"');
      expect(sanitized).toContain('time="1.234"');

      // Verify the examples parse correctly
      const examples = parseJUnitXMLContentExamples(sanitized);
      expect(examples).toHaveLength(1);
      expect(examples[0].name).toBe("bin/install.e-bash.sh / Script Name Detection / should show script path");
      expect(examples[0].specFile).toBe("spec/installation_spec.sh");
    } finally {
      rmSync(tempDir, { recursive: true, force: true });
    }
  });
});
