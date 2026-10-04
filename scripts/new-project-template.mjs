// Make the local editor's New Project button start from this repo's
// extensions. The template it copies is baked into the installed target
// under node_modules, so this runs again after every install.
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const built = join(root, "node_modules", "pxt-microbit", "built");
const project = JSON.parse(readFileSync(join(root, "pxt.json"), "utf8"));

// Stock radio is left out: the Nezbot extension drives the radio itself.
const dependencies = { core: "*", microphone: "*" };
for (const [name, source] of Object.entries(project.dependencies)) {
    if (source.startsWith("github:League-Robotics/")) dependencies[name] = source;
}

function patch(bundle) {
    const config = bundle.blocksprj && bundle.blocksprj.config;
    if (!config) return false;
    if (JSON.stringify(config.dependencies) === JSON.stringify(dependencies)
        && config.languageRestriction === project.languageRestriction) return false;
    config.dependencies = dependencies;
    config.languageRestriction = project.languageRestriction;
    return true;
}

let changed = 0;
for (const name of ["target.json", "targetlight.json", "target.js", "targetlight.js"]) {
    const path = join(built, name);
    if (!existsSync(path)) continue;
    const text = readFileSync(path, "utf8");
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}") + 1;
    const bundle = JSON.parse(text.slice(start, end));
    if (!patch(bundle)) continue;
    writeFileSync(path, text.slice(0, start) + JSON.stringify(bundle) + text.slice(end));
    changed++;
}

const list = Object.keys(dependencies).join(", ");
console.log(changed > 0
    ? `New projects now start with: ${list}`
    : `New projects already start with: ${list}`);
