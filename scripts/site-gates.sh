#!/bin/bash
# site-gates.sh — the landing page's source gates, S-1..S-10, in ui-gates.sh's idiom
# (Ferry's scripts/ui-gates.sh: red(), rc=0 per gate, `|| true` on every count, a
# $TMP from mktemp with a trap, `command grep`; controls FIRST — a gate is believed
# only after its net has been seen to catch a mutation).
#
# Usage:  bash scripts/site-gates.sh                 # from the site root; all ten
#         FERRY_SITE_GATES="s3 s7" bash scripts/site-gates.sh   # by name
# Prints one `S-n GREEN (…)` line per gate, `RED: …` per failure, then
# `==> site-gates: ok` or `==> site-gates: FAILED` (exit 1). perl, python3, sips,
# cmp and stat only — no npm, no node, nothing installed (06-UI-SPEC § 13).
#
# The contract is Ferry's .planning/phases/06-signed-build/06-UI-SPEC.md § 11.1
# (S-1..S-9) and 06-CONTEXT.md P6-D-20 (S-10, the privacy page). Every gate states
# what it prints when the guarded thing is absent, and that print is a failure.
# The positive controls are mutated copies (or synthetic lines) in $TMP — the
# site's analog of ui-gates.sh's plant_last: with no glob of files here, "the net
# sees the last file" becomes "the net sees the mutation".
#
#   gate  guards                                        absent -> prints
#   S-1   one source, three byte-identical copies       RED: no i/index.html — …
#         (index.html = 404.html = i/index.html)        RED: <f> differs from index.html (…)
#   S-2   Get TestFlight then Get Ferry: labels, hrefs, RED: Get TestFlight anchor … = N
#         DOM order; no TESTFLIGHT_JOIN_URL token; no    RED: Get Ferry anchor … = N …
#         target=_blank. At commit A (P6-D-18) the Get  RED: Get TestFlight (line a) does not
#         Ferry anchor is inside an HTML comment, which  precede Get Ferry (line b) — LINK-01's order
#         strip_html drops: the count is 0, $b is empty,
#         the token count is 0 (the comment is gone) —
#         so S-2 prints EXACTLY two reds at A and none
#         at B (06-10 uncomments the anchor with the link)
#   S-3   the preview card: seven og: tags exact; og.png RED: og:title = "Ferry" sites = N
#         1200x630, < 300000 bytes, and THAT drawing —   RED: no og.png (…)
#         four pixels read from a BMP (ground, ground,   RED: og.png pixel (x,y) is #RRGGBB, expected #…
#         hull, wave), ±2 per channel
#   S-4   the fallback anchor once; ferry:// twice; the  RED: Already have Ferry? Open it anchor … = N
#         invite-only display rules written exactly so; RED: ferry:// sites = N (expected exactly 2 …)
#         the path switch; no visibility/opacity hiding RED: the invite-only rule … = N
#   S-5   nothing leaves the page: zero request patterns, RED: location.hash sites = N
#         one inline script, location.hash exactly once  RED: the re-attachment line … = N
#         on the re-attachment line, no parse/log calls, RED: referrer no-referrer meta = N
#         the no-referrer meta
#   S-6   every sentence verbatim; the one sentence ×3;  RED: sentence missing from the page: "…"
#         V-2's never list and the voice list = 0 over   RED: N never-list hit(s) …
#         visible text + content= values; html lang=en
#   S-7   the AASA: valid JSON, one detail, the app id,  RED: AASA components are [...] (expected
#         components exactly ['/i/*', '/o/*']            exactly ['/i/*', '/o/*'] — P6-D-11 …)
#   S-8   Harbor's twelve variable values; exactly 18    RED: --muted: #525C67 = 0 …
#         hex literals; weights ⊆ {400,600}; sizes ⊆     RED: font-weight outside {400, 600}: …
#         {17px,2rem,1rem,0.882rem} all three rems;      RED: spacing numerals off the scale: …
#         -apple-system-body once; spacing on the 4-pt   RED: font: -apple-system-body = 0
#         scale; no animation/shadow/outline/zoom lock   RED: N 'box-shadow' …
#   S-9   the tile is render-icon.swift's drawing: the   RED: tile: '<pattern>' = N
#         seven literals once each; no gradient/opacity/ RED: tile: N 'linearGradient' …
#         img; one svg
#   S-10  privacy/index.html (P6-D-20): the four         RED: no privacy/index.html (…)
#         sentences; never list + voice list = 0; no     RED: privacy sentence missing: "…"
#         script; S-5's request patterns 0; lang=en; the RED: privacy/index.html's <style> block differs …
#         <style> block byte-identical to index.html's;
#         14 hex literals; one <a href="/">; no-referrer;
#         and index.html's footer links /privacy once
set -euo pipefail
cd "$(dirname "$0")/.."

FAILED=0
red() { echo "RED: $*"; FAILED=1; return 1; }

# Every scratch file a control writes lives here and is removed on exit.
TMP=$(mktemp -d -t site-gates)
trap 'rm -rf "$TMP"' EXIT

# --- helpers (06-UI-SPEC § 11.1 header, verbatim) ---------------------------
# strip_html FILE — the source with HTML comments removed (the commented Get
# Ferry anchor of commit A is invisible to every gate that reads this).
strip_html() { perl -0777 -pe 's/<!--.*?-->//gs' "$1"; }
# page_text FILE — the visible text plus every content="…" value; scripts,
# styles and tags fall away (hrefs go with their tags). The content= value is
# moved to just AFTER its tag's closing `>` before the tags are stripped: the
# UI-SPEC's header form substituted it in place, inside the tag, and the tag
# strip that follows ate it (S-6's control 2 measured 1 where 3 was expected,
# 2026-09-09). Written this way the value survives and the count is 3.
page_text() { strip_html "$1" | perl -0777 -pe 's/<script>.*?<\/script>//gs; s/<style>.*?<\/style>//gs; s/content="([^"]*)"([^>]*>)/$2 $1 /g; s/<[^>]+>/ /g'; }

# V-2's never list (ui-gates.sh V2_REGEX), applied to the page's visible text
# and content= values (06-UI-SPEC § 7.2), and the page's voice list (§ 7.1).
NEVER_REGEX='\b(relay|derp|direct|token|secret|key|path|offset|bytes?|log|hex|blob|sftp|ssh|tailcat|magicsock)\b|0x[0-9a-f]+|[0-9]+ ?%|\b[0-9]+([.,][0-9]+)? ?(k|m|g|t)?b\b'
VOICE_REGEX='\b(beta|build|version|install|download|app store|expire[sd]?)\b'

# S-5's request/read patterns — shared with S-10 (the privacy page loads nothing).
REQUEST_PATTERNS=('fetch(' 'XMLHttpRequest' 'sendBeacon' '<script src' '<link rel="stylesheet"' 'src="http' '@import' 'url(http' 'location.search' 'document.referrer' 'document.cookie' 'localStorage' 'location.href' 'window.open' 'http-equiv="refresh"')

# The BMP pixel reader (V-18's header parsing — ui-gates.sh V18_SCAN: pixel
# offset at byte 10, width/height at 18, bpp at 28, bottom-up unless h < 0,
# rows padded to 4 bytes, BGR order). Args: BMP, then x,y,RRGGBB triples.
# Prints `x,y,#RRGGBB` per point, with ` expected #RRGGBB` appended when the
# reading is more than ±2 per channel from the expectation.
PX_VERIFY='
import struct, sys
b = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", b, 10)[0]
w, h = struct.unpack_from("<ii", b, 18)
bpp = struct.unpack_from("<H", b, 28)[0]
top_down = h < 0
h = abs(h)
row = ((bpp * w + 31) // 32) * 4
bpx = bpp // 8
for arg in sys.argv[2:]:
    xs, ys, exp = arg.split(",")
    x, y = int(xs), int(ys)
    r = y if top_down else h - 1 - y
    p = off + r * row + x * bpx
    got = (b[p + 2], b[p + 1], b[p])
    want = tuple(int(exp[i:i + 2], 16) for i in (0, 2, 4))
    line = "%d,%d,#%02X%02X%02X" % (x, y, got[0], got[1], got[2])
    if any(abs(g - e) > 2 for g, e in zip(got, want)):
        line += " expected #%s" % exp.upper()
    print(line)
'
# V-18's control bitmap shape (ui-gates.sh v18 Control 2: 40 × 40, 24-bit,
# top-down, solid) with the ground's TRUE bytes — BGR 9E,5E,1B = #1B5E9E.
# V-18's own bytes [120, 60, 27] decode to #1B3C78 (measured 2026-09-09 by
# this reader; V-18 only needs min(R,G,B) < 128 there, so it never noticed),
# which is not the ground S-3 compares against.
BLANK_BMP='
import struct, sys
w = h = 40; row = ((24 * w + 31) // 32) * 4
px = bytes([0x9E, 0x5E, 0x1B]) * w + b"\0" * (row - 3 * w)
body = px * h
hdr = b"BM" + struct.pack("<IHHI", 54 + len(body), 0, 0, 54)
dib = struct.pack("<iiiHHIIiiII", 40, w, -h, 1, 24, 0, len(body), 2835, 2835, 0, 0)
open(sys.argv[1], "wb").write(hdr + dib + body)
'

# ---------------------------------------------------------------------------
# S-1 — one source, three byte-identical copies (§ 5.1, D-1). Absent (8400e2e):
# `RED: no i/index.html — …` (measured: absent; 404.html identical).
s1() {
  local rc=0 f
  # Control: cmp must see one appended byte.
  cp index.html "$TMP/copy.html"; printf 'x' >> "$TMP/copy.html"
  if cmp -s index.html "$TMP/copy.html"; then red "control: cmp did not see one appended byte"; return 1; fi
  echo "    control ok (cmp sees one appended byte on a \$TMP copy)"
  for f in 404.html i/index.html; do
    test -f "$f" || { red "no $f — /i/ answers 404 without i/index.html, and 404.html is every other path"; rc=1; continue; }
    cmp -s index.html "$f" || { red "$f differs from index.html (one source, three copies — cp it)"; rc=1; }
  done
  test "$rc" -eq 0 || return 1
  echo "S-1 GREEN (404.html and i/index.html are byte-identical to index.html)"
}

# ---------------------------------------------------------------------------
# S-2 — the two buttons, their labels, hrefs and ORDER; no token; no _blank
# (§ 5.4, LINK-01). s2_check prints problem lines for a file (no RED prefix) so
# the control can run the very code on a synthetic page and expect a problem.
S2_A='<a[^>]*id="get-testflight"[^>]*href="https://apps\.apple\.com/app/testflight/id899247664"[^>]*>Get TestFlight</a>'
S2_B='<a[^>]*id="get-ferry"[^>]*href="https://testflight\.apple\.com/join/[A-Za-z0-9]+"[^>]*>Get Ferry</a>'
s2_check() {
  local s a b n
  s=$(strip_html "$1")
  a=$(printf '%s\n' "$s" | command grep -nE "$S2_A" | cut -d: -f1 || true)
  b=$(printf '%s\n' "$s" | command grep -nE "$S2_B" | cut -d: -f1 || true)
  n=$(printf '%s\n' "$a" | command grep -c . || true)
  test "$n" -eq 1 || echo "Get TestFlight anchor (id=get-testflight, App Store id899247664, label 'Get TestFlight', one line) = $n (expected exactly 1)"
  n=$(printf '%s\n' "$b" | command grep -c . || true)
  test "$n" -eq 1 || echo "Get Ferry anchor (id=get-ferry, href testflight.apple.com/join/<code>, label 'Get Ferry', one line) = $n (expected exactly 1) — the token TESTFLIGHT_JOIN_URL is still in place, or the anchor is not on one line"
  n=$(printf '%s\n' "$s" | command grep -c 'TESTFLIGHT_JOIN_URL' || true)
  test "$n" -eq 0 || echo "TESTFLIGHT_JOIN_URL token still present ($n) — P6-D-16's public link has not been written in"
  # Both line numbers guarded: an empty $b (commit A's commented anchor) prints
  # the stated sentence with an empty number instead of a bash integer error.
  { [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; } 2>/dev/null \
    || echo "Get TestFlight (line $a) does not precede Get Ferry (line $b) — LINK-01's order"
  n=$(printf '%s\n' "$s" | command grep -c 'target="_blank"' || true)
  test "$n" -eq 0 || echo "$n target=_blank — the buttons open in the same tab"
  return 0
}
s2() {
  local rc=0 n out line
  # Control 1: the b pattern matches its expected line.
  n=$(printf '%s\n' '<a id="get-ferry" class="button prominent" href="https://testflight.apple.com/join/abc123">Get Ferry</a>' | command grep -cE "$S2_B" || true)
  test "$n" -eq 1 || { red "control: the Get Ferry pattern did not match its own expected line ($n)"; return 1; }
  # Control 2: a synthetic page with the two anchors swapped must red the order check.
  printf '%s\n' '<main>' \
    '<a id="get-ferry" class="button prominent" href="https://testflight.apple.com/join/abc123">Get Ferry</a>' \
    '<a id="get-testflight" class="button prominent" href="https://apps.apple.com/app/testflight/id899247664">Get TestFlight</a>' \
    '</main>' > "$TMP/swapped.html"
  out=$(s2_check "$TMP/swapped.html")
  printf '%s\n' "$out" | command grep -q 'does not precede' \
    || { red "control: the order check did not notice swapped anchors (got: '$(echo $out)')"; return 1; }
  echo "    control ok (the Get Ferry pattern matches its line; swapped anchors red: $(printf '%s\n' "$out" | command grep 'does not precede'))"
  out=$(s2_check index.html)
  if [ -n "$out" ]; then while IFS= read -r line; do red "$line"; done <<< "$out"; rc=1; fi
  test "$rc" -eq 0 || return 1
  echo "S-2 GREEN (Get TestFlight then Get Ferry, both hrefs real, no token, no _blank)"
}

# ---------------------------------------------------------------------------
# S-3 — the preview card (§ 6): the seven og: tags' exact values; og.png present,
# 1200 × 630, < 300 000 bytes, and THAT drawing (four pixels through a BMP).
# Geometry: side 630 centred in 1200 (x offset 285): ground at (0,0) and
# (600,100); hull at (600,368); the upper wave at (600,454) — 06-UI-SPEC § 6.
s3() {
  local rc=0 n pair p v w h sz out line bad x y rest got exp
  # Control 1: the tag pattern matches its expected line.
  n=$(printf '%s\n' '<meta property="og:title" content="Ferry">' | command grep -cF 'property="og:title" content="Ferry"' || true)
  test "$n" -eq 1 || { red "control: the og:title pattern did not match its own line ($n)"; return 1; }
  # Control 2: the pixel reader on V-18's solid-blue 40 px bitmap reports the
  # ground at (0,0) and FAILS the two white checks (scaled into the 40 px square).
  python3 -c "$BLANK_BMP" "$TMP/blank40.bmp"
  out=$(python3 -c "$PX_VERIFY" "$TMP/blank40.bmp" 0,0,1B5E9E 20,10,FFFFFF 20,30,FFFFFF)
  n=$(printf '%s\n' "$out" | command grep -c 'expected' || true)
  { printf '%s\n' "$out" | command grep -qx '0,0,#1B5E9E' && test "$n" -eq 2; } \
    || { red "control: the pixel reader did not fail on a solid blue image (got: $(echo $out))"; return 1; }
  echo "    control ok (og:title pattern matches; solid blue 40 px: $(printf '%s\n' "$out" | tr '\n' ';'))"
  for pair in 'og:title|Ferry' 'og:description|Send photos and files straight to people you know.' 'og:image|https://ferry.indiagram.com/og.png' 'og:image:width|1200' 'og:image:height|630' 'og:url|https://ferry.indiagram.com/' 'og:type|website'; do
    p=${pair%%|*}; v=${pair#*|}
    n=$(strip_html index.html | command grep -cF "property=\"$p\" content=\"$v\"" || true)
    test "$n" -eq 1 || { red "$p = \"$v\" sites = $n (expected exactly 1)"; rc=1; }
  done
  test -f og.png || { red "no og.png (§ 6: rendered by scripts/icon/render-icon.swift's third output, copied here)"; return 1; }
  w=$(sips -g pixelWidth og.png 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight og.png 2>/dev/null | awk '/pixelHeight/{print $2}')
  [ "$w" = 1200 ] && [ "$h" = 630 ] || { red "og.png is ${w}x${h}, expected 1200x630"; rc=1; }
  sz=$(stat -f%z og.png)
  test "$sz" -lt 300000 || { red "og.png is $sz bytes (expected < 300000 — WhatsApp compresses above ~300 KB)"; rc=1; }
  sips -s format bmp og.png --out "$TMP/og.bmp" >/dev/null 2>&1 || { red "sips could not convert og.png to BMP"; return 1; }
  out=$(python3 -c "$PX_VERIFY" "$TMP/og.bmp" 0,0,1B5E9E 600,100,1B5E9E 600,368,FFFFFF 600,454,FFFFFF)
  echo "    og.png pixels (x,y,#RRGGBB; ground, ground, hull, wave): $(printf '%s\n' "$out" | tr '\n' ' ')"
  bad=$(printf '%s\n' "$out" | command grep 'expected' || true)
  if [ -n "$bad" ]; then
    # red() must run in this shell (FAILED lives here) — never behind a pipe.
    while IFS= read -r line; do
      x=${line%%,*}; rest=${line#*,}; y=${rest%%,*}; rest=${rest#*,}; got=${rest%% *}; exp=${rest##* }
      red "og.png pixel ($x,$y) is $got, expected $exp — the image is not render-icon's drawing at side 630 centred"
    done <<< "$bad"; rc=1
  fi
  test "$rc" -eq 0 || return 1
  echo "S-3 GREEN (seven og: tags exact; og.png ${w}x${h}, $sz bytes; ground/hull/wave pixels as drawn)"
}

# ---------------------------------------------------------------------------
# S-4 — the fallback exists once, lives in the invite-only set, and the invite
# set is switched by the path prefix (§ 5.1, § 5.5).
S4_ANCHOR='<a[^>]*id="open-ferry"[^>]*href="ferry://i"[^>]*>Already have Ferry\? Open it</a>'
S4_NONE='#invite, #again, #open-ferry \{ display: none; \}'
S4_BLOCK='body\.is-invite #invite, body\.is-invite #again, body\.is-invite #open-ferry \{ display: block; \}'
s4() {
  local rc=0 s n
  # Controls: each pattern over its expected line = 1; the none-rule with
  # #open-ferry deleted must NOT match (the net sees the fallback leaving the set).
  n=$(printf '%s\n' '<a id="open-ferry" class="button secondary" href="ferry://i">Already have Ferry? Open it</a>' | command grep -cE "$S4_ANCHOR" || true)
  test "$n" -eq 1 || { red "control: the fallback anchor pattern did not match its own line ($n)"; return 1; }
  n=$(printf '%s\n' '    #invite, #again, #open-ferry { display: none; }' | command grep -cE "$S4_NONE" || true)
  test "$n" -eq 1 || { red "control: the invite-only rule pattern did not match its own line ($n)"; return 1; }
  n=$(printf '%s\n' '    body.is-invite #invite, body.is-invite #again, body.is-invite #open-ferry { display: block; }' | command grep -cE "$S4_BLOCK" || true)
  test "$n" -eq 1 || { red "control: the invite rule pattern did not match its own line ($n)"; return 1; }
  printf '%s\n' '    #invite, #again { display: none; }' > "$TMP/left-the-set.css"
  n=$(command grep -cE "$S4_NONE" "$TMP/left-the-set.css" || true)
  test "$n" -eq 0 || { red "control: the invite-only net did not notice the fallback leaving the set ($n)"; return 1; }
  echo "    control ok (three patterns match their lines; a rule without #open-ferry counts 0)"
  s=$(strip_html index.html)
  n=$(printf '%s\n' "$s" | command grep -cE "$S4_ANCHOR" || true)
  test "$n" -eq 1 || { red "Already have Ferry? Open it anchor (id=open-ferry, href=ferry://i, one line) = $n (expected exactly 1)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -c 'ferry://' || true)
  test "$n" -eq 2 || { red "ferry:// sites = $n (expected exactly 2: the anchor's href and the script's 'ferry://i' + location.hash)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -cE "$S4_NONE" || true)
  test "$n" -eq 1 || { red "the invite-only rule '#invite, #again, #open-ferry { display: none; }' = $n (expected exactly 1, written exactly so)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -cE "$S4_BLOCK" || true)
  test "$n" -eq 1 || { red "the invite rule 'body.is-invite … { display: block; }' = $n (expected exactly 1)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -cF "location.pathname.indexOf('/i/') === 0" || true)
  test "$n" -eq 1 || { red "the path switch location.pathname.indexOf('/i/') === 0 = $n (expected exactly 1)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -cE 'visibility: *hidden|opacity: *0' || true)
  test "$n" -eq 0 || { red "$n visibility:hidden/opacity:0 — hidden things are display:none (out of the accessibility tree)"; rc=1; }
  test "$rc" -eq 0 || return 1
  echo "S-4 GREEN (the fallback once, in the invite-only set, switched by the path prefix)"
}

# ---------------------------------------------------------------------------
# S-5 — the fragment never leaves, and nothing else does (§ 5.8): zero request
# patterns; one inline script; location.hash exactly once, on the re-attachment
# line; nothing decodes, splits, inspects or logs; the no-referrer meta.
s5() {
  local rc=0 s n pat fn
  # Controls: the shapes the gate exists to refuse are seen.
  n=$(printf '%s\n' 'x=fetch("a")' | command grep -cF 'fetch(' || true)
  test "$n" -eq 1 || { red "control: 'fetch(' not seen in x=fetch(\"a\") ($n)"; return 1; }
  n=$(printf '%s\n' "open.href = 'ferry://i' + decodeURIComponent(location.hash)" | command grep -cF 'decodeURIComponent' || true)
  test "$n" -eq 1 || { red "control: decodeURIComponent not seen on the decoding line ($n)"; return 1; }
  echo "    control ok (fetch( and decodeURIComponent(location.hash) are each seen once)"
  s=$(strip_html index.html)
  for pat in "${REQUEST_PATTERNS[@]}"; do
    n=$(printf '%s\n' "$s" | command grep -cF "$pat" || true)
    test "$n" -eq 0 || { red "$n '$pat' — the page makes no request and reads nothing but its path and hash"; rc=1; }
  done
  n=$(printf '%s\n' "$s" | command grep -c '<script' || true)
  test "$n" -eq 1 || { red "script blocks = $n (expected exactly 1, inline)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -c 'location.hash' || true)
  test "$n" -eq 1 || { red "location.hash sites = $n (expected exactly 1: the fallback's re-attachment)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -cF "open.href = 'ferry://i' + location.hash" || true)
  test "$n" -eq 1 || { red "the re-attachment line \"open.href = 'ferry://i' + location.hash\" = $n (expected exactly 1, written exactly so — the hash is appended whole, never decoded or split)"; rc=1; }
  for fn in decodeURIComponent 'split(' 'substring(' 'slice(' 'replace(' 'match(' 'console.'; do
    n=$(printf '%s\n' "$s" | command grep -cF "$fn" || true)
    test "$n" -eq 0 || { red "$n '$fn' in the page — nothing parses, inspects or logs the fragment"; rc=1; }
  done
  n=$(printf '%s\n' "$s" | command grep -cF '<meta name="referrer" content="no-referrer">' || true)
  test "$n" -eq 1 || { red "referrer no-referrer meta = $n (expected 1)"; rc=1; }
  test "$rc" -eq 0 || return 1
  echo "S-5 GREEN (zero requests; one inline script; location.hash once, appended whole; no-referrer)"
}

# ---------------------------------------------------------------------------
# S-6 — every sentence is the contract's (§ 7.1) and the never list holds over
# visible text and content= values (§ 7.2).
THE_SENTENCE='Send photos and files straight to people you know.'
s6() {
  local rc=0 t n str
  # Control 1: the never list sees `relay` and `path` on a line (one line = 1).
  printf '%s\n' '<p>the relay path</p>' > "$TMP/never.html"
  n=$(page_text "$TMP/never.html" | command grep -cEi "$NEVER_REGEX" || true)
  test "$n" -eq 1 || { red "control: the never list did not see 'the relay path' ($n; two hits on one line count as 1 line)"; return 1; }
  # Control 2: a synthetic page with the sentence three times counts 3; with
  # its #what deleted the "exactly 3" check must red (count 2).
  printf '%s\n' "<meta name=\"description\" content=\"$THE_SENTENCE\">" \
    "<meta property=\"og:description\" content=\"$THE_SENTENCE\">" \
    "<p id=\"what\">$THE_SENTENCE</p>" > "$TMP/three.html"
  n=$(page_text "$TMP/three.html" | command grep -cF "$THE_SENTENCE" || true)
  test "$n" -eq 3 || { red "control: the synthetic three-sentence page counts $n (expected 3)"; return 1; }
  command grep -v 'id="what"' "$TMP/three.html" > "$TMP/two.html"
  n=$(page_text "$TMP/two.html" | command grep -cF "$THE_SENTENCE" || true)
  test "$n" -eq 2 || { red "control: deleting #what left the count at $n (expected 2 — the exactly-3 check could not red)"; return 1; }
  echo "    control ok (never list sees 'the relay path'; the sentence counts 3, then 2 with #what deleted)"
  t=$(page_text index.html)
  for str in "$THE_SENTENCE" 'Someone invited you to share with them on Ferry.' 'Ferry is in private testing. It comes through Apple'"'"'s TestFlight app, so getting it takes two steps.' 'Then go back to the message and tap the invite link again. That'"'"'s what pairs you.' 'Made by'; do
    n=$(printf '%s\n' "$t" | command grep -cF "$str" || true)
    test "$n" -ge 1 || { red "sentence missing from the page: \"$str\""; rc=1; }
  done
  n=$(printf '%s\n' "$t" | command grep -cF "$THE_SENTENCE" || true)
  test "$n" -eq 3 || { red "the one sentence appears $n times (expected exactly 3: #what, description, og:description)"; rc=1; }
  n=$(printf '%s\n' "$t" | command grep -cEi "$NEVER_REGEX" || true)
  test "$n" -eq 0 || { red "$n never-list hit(s) in the page's visible text / content= values"; rc=1; }
  n=$(printf '%s\n' "$t" | command grep -cEi "$VOICE_REGEX" || true)
  test "$n" -eq 0 || { red "$n word(s) outside the page's voice (beta/build/version/install/download/app store/expire) — § 7.1"; rc=1; }
  n=$(command grep -c '<html lang="en">' index.html || true)
  test "$n" -eq 1 || { red "html lang=en = $n"; rc=1; }
  test "$rc" -eq 0 || return 1
  echo "S-6 GREEN (the five strings present, the one sentence ×3, never list 0, voice list 0, lang=en)"
}

# ---------------------------------------------------------------------------
# S-7 — the AASA (§ 5.1): valid JSON, one detail block, the app id, components
# exactly ['/i/*', '/o/*']. s7_check prints problem lines (no RED prefix).
S7_PY='
import json, sys
j = json.load(open(sys.argv[1]))
d = j["applinks"]["details"]
if len(d) != 1:
    print("AASA details has %d blocks (expected exactly 1)" % len(d)); sys.exit(0)
if d[0].get("appIDs") != ["G5H628C6WR.com.indiagram.ferry"]:
    print("AASA appIDs are %r (expected exactly [%r])" % (d[0].get("appIDs"), "G5H628C6WR.com.indiagram.ferry"))
c = [x.get("/") for x in d[0].get("components", [])]
if c != ["/i/*", "/o/*"]:
    print("AASA components are %r (expected exactly [%r, %r] — P6-D-11: every v0.2 path before the first upload)" % (c, "/i/*", "/o/*"))
'
s7_check() { python3 -c "$S7_PY" "$1"; }
s7() {
  local rc=0 A=.well-known/apple-app-site-association out line
  # Controls on synthetic JSON: the good shape prints nothing; /o/* removed
  # reds; a third component reds.
  printf '%s\n' '{"applinks":{"details":[{"appIDs":["G5H628C6WR.com.indiagram.ferry"],"components":[{"/":"/i/*"},{"/":"/o/*"}]}]}}' > "$TMP/aasa-good.json"
  printf '%s\n' '{"applinks":{"details":[{"appIDs":["G5H628C6WR.com.indiagram.ferry"],"components":[{"/":"/i/*"}]}]}}' > "$TMP/aasa-no-o.json"
  printf '%s\n' '{"applinks":{"details":[{"appIDs":["G5H628C6WR.com.indiagram.ferry"],"components":[{"/":"/i/*"},{"/":"/o/*"},{"/":"/x/*"}]}]}}' > "$TMP/aasa-third.json"
  out=$(s7_check "$TMP/aasa-good.json"); [ -z "$out" ] || { red "control: the good AASA shape printed a problem: $out"; return 1; }
  out=$(s7_check "$TMP/aasa-no-o.json"); printf '%s\n' "$out" | command grep -q "components are \['/i/\*'\]" || { red "control: /o/* removed was not noticed (got: '$out')"; return 1; }
  out=$(s7_check "$TMP/aasa-third.json"); printf '%s\n' "$out" | command grep -q "components are \['/i/\*', '/o/\*', '/x/\*'\]" || { red "control: a third component was not noticed (got: '$out')"; return 1; }
  echo "    control ok (good shape silent; /o/* removed reds; a third component reds)"
  test -f "$A" || { red "no $A"; return 1; }
  python3 -m json.tool "$A" >/dev/null 2>&1 || { red "$A is not valid JSON"; return 1; }
  out=$(s7_check "$A")
  if [ -n "$out" ]; then while IFS= read -r line; do red "$line"; done <<< "$out"; rc=1; fi
  test "$rc" -eq 0 || return 1
  echo "S-7 GREEN (AASA: one detail, G5H628C6WR.com.indiagram.ferry, components ['/i/*', '/o/*'])"
}

# ---------------------------------------------------------------------------
# S-8 — Harbor's tokens and scale (§ 2–4).
s8() {
  local rc=0 s n kv k v bad pat
  # Controls: the weight net prints 700; the scale net prints 28px.
  bad=$(printf 'font-weight: 700\n' | command grep -oE 'font-weight: *[0-9]+' | command grep -vE ': *(400|600)$' || true)
  [ "$bad" = "font-weight: 700" ] || { red "control: the weight net did not print 'font-weight: 700' (got '$bad')"; return 1; }
  bad=$(printf 'padding: 0 28px;\n' | command grep -oE '(padding|gap|margin)(-[a-z]+)?: *[^;]+' | command grep -oE '[0-9]+px' | command grep -vE '^(0|4|8|16|24|32|48|64)px$' || true)
  [ "$bad" = "28px" ] || { red "control: the scale net did not see 28px (got '$bad')"; return 1; }
  echo "    control ok (weight net prints 700; scale net prints 28px)"
  s=$(strip_html index.html)
  for kv in 'bg|F2F3F6' 'surface|FFFFFF' 'ink|0E1C2A' 'muted|525C67' 'accent|1B5E9E' 'on-accent|FFFFFF' 'bg|000000' 'surface|161C24' 'ink|F2F4F7' 'muted|A9ABAD' 'accent|5B9BE0' 'on-accent|161C24'; do
    k=${kv%%|*}; v=${kv#*|}
    n=$(printf '%s\n' "$s" | command grep -cE -- "--$k: *#$v\b" || true)
    test "$n" -eq 1 || { red "--$k: #$v = $n (expected exactly 1 — Harbor's value, § 4)"; rc=1; }
  done
  n=$(printf '%s\n' "$s" | command grep -oE '#[0-9A-Fa-f]{3,8}\b' | command grep -c . || true)
  test "$n" -eq 18 || { red "hex colour literals = $n (expected exactly 18: the 12 variable values, the SVG's #1B5E9E ground and three #FFFFFF fills/stroke, the 2 theme-colors) — a new hex is a colour outside Harbor"; rc=1; }
  bad=$(printf '%s\n' "$s" | command grep -oE 'font-weight: *[0-9]+' | command grep -vE ': *(400|600)$' || true)
  [ -z "$bad" ] || { red "font-weight outside {400, 600}: $(printf '%s' "$bad" | tr '\n' ' ')"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -cE 'font-weight: *600' || true)
  test "$n" -ge 1 || { red "no font-weight: 600 (the title and the buttons)"; rc=1; }
  bad=$(printf '%s\n' "$s" | command grep -oE 'font-size: *[0-9.]+(px|rem|em|%)' | command grep -vE ': *(17px|2rem|1rem|0\.882rem)$' || true)
  [ -z "$bad" ] || { red "font-size outside {17px, 2rem, 1rem, 0.882rem}: $(printf '%s' "$bad" | tr '\n' ' ')"; rc=1; }
  for v in 2rem 1rem 0.882rem; do
    n=$(printf '%s\n' "$s" | command grep -cE "font-size: *$v" || true)
    test "$n" -ge 1 || { red "font-size: $v absent (the three sizes, § 3)"; rc=1; }
  done
  n=$(printf '%s\n' "$s" | command grep -cF 'font: -apple-system-body' || true)
  test "$n" -eq 1 || { red "font: -apple-system-body = $n (expected 1 — Dynamic Type, § 3)"; rc=1; }
  bad=$(printf '%s\n' "$s" | command grep -oE '(padding|gap|margin)(-[a-z]+)?: *[^;]+' | command grep -oE '[0-9]+px' | command grep -vE '^(0|4|8|16|24|32|48|64)px$' || true)
  [ -z "$bad" ] || { red "spacing numerals off the scale: $(printf '%s' "$bad" | tr '\n' ' ')"; rc=1; }
  for pat in 'animation' 'transition' 'outline: *none' 'outline: *0' 'maximum-scale' 'user-scalable' 'text-transform' 'font-style: *italic' 'text-shadow' 'box-shadow' 'nowrap'; do
    n=$(printf '%s\n' "$s" | command grep -cE "$pat" || true)
    test "$n" -eq 0 || { red "$n '$pat' (§ 5.8, § 8, § 3)"; rc=1; }
  done
  test "$rc" -eq 0 || return 1
  echo "S-8 GREEN (Harbor's twelve values, 18 hex literals, weights {400,600}, three rem sizes over -apple-system-body, spacing on the scale, nothing animated or shadowed)"
}

# ---------------------------------------------------------------------------
# S-9 — the tile is render-icon.swift's drawing (§ 5.6).
s9() {
  local rc=0 s n pat
  n=$(printf '%s\n' '<path d="M184.32 737.28H839.68"/>' | command grep -cF 'M184.32 737.28H839.68' || true)
  test "$n" -eq 1 || { red "control: the wave pattern did not match its own line ($n)"; return 1; }
  echo "    control ok (the wave path pattern matches its line)"
  s=$(strip_html index.html)
  for pat in '<div id="tile" aria-hidden="true">' 'viewBox="0 0 1024 1024"' '<rect width="1024" height="1024" fill="#1B5E9E"/>' 'stroke-width="42.67"' 'M184.32 737.28H839.68' 'M184.32 860.16H839.68' 'points="184.32,491.52 839.68,491.52 778.24,614.4 245.76,614.4"'; do
    n=$(printf '%s\n' "$s" | command grep -cF "$pat" || true)
    test "$n" -eq 1 || { red "tile: '$pat' = $n (expected exactly 1 — render-icon.swift's numbers, § 5.6)"; rc=1; }
  done
  for pat in 'linearGradient' 'radialGradient' 'opacity=' '<img'; do
    n=$(printf '%s\n' "$s" | command grep -cF "$pat" || true)
    test "$n" -eq 0 || { red "tile: $n '$pat' — the icon is flat, one drawing, inline"; rc=1; }
  done
  n=$(printf '%s\n' "$s" | command grep -c '<svg' || true)
  test "$n" -eq 1 || { red "svg elements = $n (expected exactly 1)"; rc=1; }
  test "$rc" -eq 0 || return 1
  echo "S-9 GREEN (the tile is render-icon's drawing: 1024 viewBox, flat #1B5E9E, waves 737.28/860.16, stroke 42.67, no gradient)"
}

# ---------------------------------------------------------------------------
# S-10 — privacy/index.html (P6-D-20): the four sentences verbatim, in Ferry's
# voice, loading nothing, under index.html's own <style> block, linked from
# the landing page's footer. Its URL is the value of BETA_APP_PRIVACY_URL.
PRIVACY_1='Ferry has no account and no server of its own. Nothing about you or what you share is collected or sent to indiagram.'
PRIVACY_2='What you share goes from your phone to the person you chose, encrypted on the way, and is not kept anywhere in between.'
PRIVACY_3='Ferry keeps a short record on your phone of what it did, so you can send a report if something goes wrong. You choose when to send it and who gets it. It says what Ferry did and when, with names taken out, and it never includes your photos or files.'
PRIVACY_4='Ferry has no analytics, no ads and no tracking. This page loads nothing from anywhere else.'
s10() {
  local rc=0 t s n str pat P=privacy/index.html
  # Controls on a synthetic privacy page: sentence 1 deleted must red the
  # sentence check; `relay` inserted into a paragraph must red the never list.
  printf '%s\n' "<p>$PRIVACY_1</p>" "<p>$PRIVACY_2</p>" "<p>$PRIVACY_3</p>" "<p>$PRIVACY_4</p>" > "$TMP/privacy-good.html"
  t=$(page_text "$TMP/privacy-good.html")
  n=$(printf '%s\n' "$t" | command grep -cF "$PRIVACY_1" || true)
  test "$n" -eq 1 || { red "control: the synthetic privacy page does not carry sentence 1 ($n)"; return 1; }
  command grep -vF "$PRIVACY_1" "$TMP/privacy-good.html" > "$TMP/privacy-minus-1.html"
  n=$(page_text "$TMP/privacy-minus-1.html" | command grep -cF "$PRIVACY_1" || true)
  test "$n" -eq 0 || { red "control: deleting sentence 1 left it findable ($n)"; return 1; }
  sed 's/no server of its own/no relay server of its own/' "$TMP/privacy-good.html" > "$TMP/privacy-relay.html"
  n=$(page_text "$TMP/privacy-relay.html" | command grep -cEi "$NEVER_REGEX" || true)
  test "$n" -eq 1 || { red "control: the never list did not see an inserted 'relay' in a privacy paragraph ($n)"; return 1; }
  echo "    control ok (sentence 1 deleted reds: privacy sentence missing; an inserted 'relay' reds: 1 never-list hit)"
  test -f "$P" || { red "no $P (P6-D-20; BETA_APP_PRIVACY_URL points here)"; return 1; }
  t=$(page_text "$P")
  s=$(strip_html "$P")
  for str in "$PRIVACY_1" "$PRIVACY_2" "$PRIVACY_3" "$PRIVACY_4"; do
    n=$(printf '%s\n' "$t" | command grep -cF "$str" || true)
    test "$n" -ge 1 || { red "privacy sentence missing: \"$str\""; rc=1; }
  done
  n=$(printf '%s\n' "$t" | command grep -cEi "$NEVER_REGEX" || true)
  test "$n" -eq 0 || { red "$n never-list hit(s) in the privacy page's visible text / content= values"; rc=1; }
  n=$(printf '%s\n' "$t" | command grep -cEi "$VOICE_REGEX" || true)
  test "$n" -eq 0 || { red "$n word(s) outside Ferry's voice on the privacy page (beta/build/version/install/download/app store/expire)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -c '<script' || true)
  test "$n" -eq 0 || { red "script blocks on the privacy page = $n (expected 0 — it loads and runs nothing)"; rc=1; }
  for pat in "${REQUEST_PATTERNS[@]}"; do
    n=$(printf '%s\n' "$s" | command grep -cF "$pat" || true)
    test "$n" -eq 0 || { red "$n '$pat' on the privacy page — it makes no request"; rc=1; }
  done
  n=$(command grep -c '<html lang="en">' "$P" || true)
  test "$n" -eq 1 || { red "privacy html lang=en = $n"; rc=1; }
  sed -n '/<style>/,/<\/style>/p' index.html > "$TMP/style-index.css"
  sed -n '/<style>/,/<\/style>/p' "$P" > "$TMP/style-privacy.css"
  test -s "$TMP/style-privacy.css" && cmp -s "$TMP/style-index.css" "$TMP/style-privacy.css" \
    || { red "privacy/index.html's <style> block differs from index.html's (one design — copy it)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -oE '#[0-9A-Fa-f]{3,8}\b' | command grep -c . || true)
  test "$n" -eq 14 || { red "privacy hex colour literals = $n (expected exactly 14: the 12 variable values and the 2 theme-colors; the privacy page has no tile)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -cF '<a href="/">' || true)
  test "$n" -eq 1 || { red "privacy <a href=\"/\"> = $n (expected exactly 1 — the way back)"; rc=1; }
  n=$(printf '%s\n' "$s" | command grep -cF '<meta name="referrer" content="no-referrer">' || true)
  test "$n" -eq 1 || { red "privacy referrer no-referrer meta = $n (expected 1)"; rc=1; }
  n=$(strip_html index.html | command grep -cF '<a href="/privacy">Privacy</a>' || true)
  test "$n" -eq 1 || { red "index.html footer link <a href=\"/privacy\">Privacy</a> = $n (expected exactly 1 — P6-D-20: linked from the footer)"; rc=1; }
  test "$rc" -eq 0 || return 1
  echo "S-10 GREEN (privacy/index.html: the four sentences, never/voice lists 0, no script, no request, index.html's style block, 14 hex literals, the way back; the footer links /privacy)"
}

# ---------------------------------------------------------------------------
# The runner (ui-gates.sh's): FERRY_SITE_GATES selects by name; a name that is
# not a function is RED, not skipped — a typo must not print ok.
GATES="${FERRY_SITE_GATES:-s1 s2 s3 s4 s5 s6 s7 s8 s9 s10}"
for g in $GATES; do
  declare -F "$g" >/dev/null || { echo "RED: no gate named $g"; FAILED=1; continue; }
  "$g" || true
done
if [ "$FAILED" -ne 0 ]; then
  echo "==> site-gates: FAILED" >&2
  exit 1
fi
echo "==> site-gates: ok"
