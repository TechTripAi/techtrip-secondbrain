#!/usr/bin/env node
// Context-specific encoding for untrusted metadata used by the source skills.
// Usage: node scripts/encode-text.js yaml|yaml-inner|markdown|plain <value>

function normalize(value) {
  return String(value ?? "")
    .replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]+/gu, " ")
    .replace(/\s+/gu, " ")
    .trim();
}

function yamlScalar(value) {
  return JSON.stringify(normalize(value));
}

function yamlInner(value) {
  return yamlScalar(value).slice(1, -1);
}

function markdownInline(value) {
  return normalize(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/([\\`*_[\]])/g, "\\$1");
}

module.exports = { normalize, yamlScalar, yamlInner, markdownInline };

if (require.main === module) {
  const [mode, value = ""] = process.argv.slice(2);
  const encoders = { yaml: yamlScalar, "yaml-inner": yamlInner, markdown: markdownInline, plain: normalize };
  if (!encoders[mode]) {
    process.stderr.write("usage: encode-text.js yaml|yaml-inner|markdown|plain <value>\n");
    process.exit(2);
  }
  process.stdout.write(encoders[mode](value));
}
