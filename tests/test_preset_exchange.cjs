const fs = require('fs'), vm = require('vm'), assert = require('assert');
const html = fs.readFileSync('docs/website/index.html', 'utf8');
const appJs = fs.existsSync('docs/website/app.js') ? fs.readFileSync('docs/website/app.js', 'utf8') : html;
const context = vm.createContext({});
vm.runInContext(fs.readFileSync('package/contents/ui/studio/PresetCodec.js', 'utf8'), context);
vm.runInContext(fs.readFileSync('hyprland/Configuration.js', 'utf8'), context);
context.xml = fs.readFileSync('package/contents/config/main.xml', 'utf8');
const jsSource = appJs.includes('const EXISTING =') ? appJs : html;
vm.runInContext(jsSource.slice(jsSource.indexOf('const EXISTING ='), jsSource.indexOf('const VIZ =')) + '\nvar webDefaults = DEFAULTS; var webKnown = LOOK_DEFAULTS; var qmlKnown = defaults(xml);', context);
vm.runInContext(`
var cases = [webDefaults,
 Object.assign({}, webDefaults, {layoutMode:'compact', surfaceStyle:'art', detailFields:'album,genre', titleSize:14}),
 Object.assign({}, webDefaults, {layoutMode:'orbit', detailFields:'', customColor:'#55ffcc'})];
var results = cases.map(function(state) {
 var text = PresetCodec.encode('Shared', state, webKnown, true);
 var qml = PresetCodec.decode(text, qmlKnown, false);
 var back = PresetCodec.decode(PresetCodec.encode(qml.name, Object.assign({}, qmlKnown, qml.settings), qmlKnown, false), webKnown, true);
 return {state:state, qml:qml.settings, back:back.settings};
});`, context);
for (const {state,qml,back} of context.results) {
 assert.equal(back.layoutMode, state.layoutMode);
 assert.equal(back.surfaceStyle, state.surfaceStyle);
 assert.equal(back.detailFields, state.detailFields);
 assert.equal(back.titleSize, state.titleSize);
 assert(!('userPresets' in qml));
}
const script = html.includes('<script>\n') ? html.split('<script>\n')[1].split('</script>')[0] : appJs;
new vm.Script(script);
assert(!html.includes('Has new options'));
assert(!html.includes('.tabs .dot'));
console.log('PASS: actual HTML and main.xml defaults, bidirectional presets, script syntax, no tab dots');
