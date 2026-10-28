"""Retire le code de son propre au canevas (bouton haut-parleur, sons embarqués)."""
import re
def strip(s):
    s = re.sub(r'<button type="button" aria-label="\{\{sndLabel\}\}".*?</button>\n?', "", s, flags=re.S)
    if "_sndCfg()" in s:
        a = s.index("  _sndCfg() {")
        b = s.rindex("}\n</script>")
        s = s[:a].rstrip("\n") + "\n" + s[b:]
        s = s.replace("  _rv0() {", "  renderVals() {")
        s = s.replace("    if (this._sndStop) this._sndStop();\n", "")
    return s
