// Read the same defaults KConfig uses for Plasma; do not maintain a second list.
function defaults(xml) {
    const result = {};
    const entries = /<entry\s+name="([^"]+)"\s+type="([^"]+)"\s*>\s*<default>([^<]*)<\/default>/g;
    let entry;
    while ((entry = entries.exec(xml)) !== null) {
        const type = entry[2];
        const value = entry[3];
        result[entry[1]] = type === "Bool" ? value === "true"
            : type === "Int" || type === "Double" ? Number(value)
            : type === "StringList" ? (value ? value.split(",") : [])
            : value;
    }
    return result;
}

function parsePreferences(text) {
    const value = JSON.parse(text);
    if (!value || typeof value !== "object" || Array.isArray(value))
        throw new Error("expected a settings object");
    return value;
}

function overrides(baseline, draft) {
    const result = {};
    for (const key of Object.keys(draft)) {
        const value = draft[key];
        const original = baseline[key];
        // A saved StringList is a new array after JSON reload. Compare its
        // contents so an unchanged list keeps following declarative defaults.
        const sameList = Array.isArray(value) && Array.isArray(original)
            && value.length === original.length
            && value.every((item, index) => item === original[index]);
        if (value !== original && !sameList)
            result[key] = draft[key];
    }
    return result;
}

function screens(available, monitor) {
    if (monitor === "all") return available;
    const selected = available.find(screen => screen.name === monitor) || available[0];
    return selected ? [selected] : [];
}
