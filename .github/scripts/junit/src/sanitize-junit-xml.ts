#!/usr/bin/env bun
/**
 * Sanitize JUnit XML by stripping everything except testcase attributes we actually use:
 *   - classname (spec file)
 *   - name (example name)
 *   - time (seconds)
 *
 * Usage:
 *   bun sanitize-junit-xml.ts <output_xml> <input_xml_files...>
 */

import { readFileSync, writeFileSync } from "node:fs";

function extractAttribute(tag: string, attrName: string): string | null {
    const match = tag.match(new RegExp(`${attrName}="([^"]*)"`, "i"));
    return match ? match[1] : null;
}

function extractTestcases(xml: string): Array<{ classname: string; name: string; time: string }> {
    const testcaseRegex = /<testcase[^>]*>/g;
    const matches = xml.match(testcaseRegex) ?? [];
    const out: Array<{ classname: string; name: string; time: string }> = [];

    for (const tag of matches) {
        const classname = extractAttribute(tag, "classname") ?? "";
        const name = extractAttribute(tag, "name") ?? "";
        const time = extractAttribute(tag, "time") ?? "0";

        if (!classname && !name) continue;
        out.push({ classname, name, time });
    }

    return out;
}

function buildSanitizedXml(testcases: Array<{ classname: string; name: string; time: string }>): string {
    const lines: string[] = [];
    lines.push('<?xml version="1.0" encoding="UTF-8"?>');
    lines.push("<testsuites>");
    for (const tc of testcases) {
        const attrs: string[] = [];
        if (tc.classname) attrs.push(`classname="${tc.classname}"`);
        if (tc.name) attrs.push(`name="${tc.name}"`);
        if (tc.time) attrs.push(`time="${tc.time}"`);
        lines.push(`  <testcase ${attrs.join(" ")}/>`);
    }
    lines.push("</testsuites>");
    lines.push("");
    return lines.join("\n");
}

function main() {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.error("Usage: bun sanitize-junit-xml.ts <output_xml> <input_xml_files...>");
        process.exit(1);
    }

    const [outputFile, ...inputFiles] = args;
    const all: Array<{ classname: string; name: string; time: string }> = [];

    for (const input of inputFiles) {
        try {
            const xml = readFileSync(input, "utf-8");
            all.push(...extractTestcases(xml));
        } catch (error) {
            console.error(`Warning: failed to read ${input}:`, error);
        }
    }

    if (all.length === 0) {
        console.error("Error: no <testcase> tags found in input XML.");
        process.exit(2);
    }

    const sanitized = buildSanitizedXml(all);
    writeFileSync(outputFile, sanitized);
}

main();

