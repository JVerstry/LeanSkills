-- GENERATED FILE (task T29) -- do not edit by hand.
-- Regenerate with `python scripts/generate_assets.py` after
-- changing a file under assets/.

namespace LeanDoc.Assets

/-- Embedded from `assets/style.css`. -/
def styleCss : String := "/* Vendored, unmodified, from doc-gen4 (task T29, 2026-09-23):
 * https://github.com/leanprover/doc-gen4/blob/main/static/style.css
 * Copyright the doc-gen4 contributors. Licensed under the Apache
 * License, Version 2.0 (see doc-gen4's own LICENSE file, or
 * https://www.apache.org/licenses/LICENSE-2.0) — same license as
 * LeanDoc itself. Deliberately matches the Lean ecosystem's own
 * documentation styling (Mathlib, cslib) rather than something
 * LeanDoc invented; if this file is ever locally modified, mark the
 * change here per the Apache-2.0 attribution requirement.
 * Periodically check for upstream changes — see wip/todo.md task T40.
 */
@import url('https://cdnjs.cloudflare.com/ajax/libs/lato-font/3.0.0/css/lato-font.min.css');
@import url('https://cdnjs.cloudflare.com/ajax/libs/juliamono/0.051/juliamono.css');

* {
    box-sizing: border-box;
}

body {
    font-size: 17px;
    font-variant-ligatures: none;
    font-family: 'Lato Medium';
    color: var(--text-color);
    background: var(--body-bg);
}

input, select, textarea, button{font-family:inherit;}

a {
   color: var(--link-color);
}

h1, h2, h3, h4, h5, h6 {
    font-family: 'Lato Medium';
}

body { line-height: 1.5; }
nav { line-height: normal; }

:root {
    --header-height: 3em;
    --fragment-offset: calc(var(--header-height) + 1em);
    --content-width: 55vw;

    --header-bg: #f8f8f8;
    --body-bg: white;
    --code-bg: #f3f3f3;
    --text-color: black;
    --link-color: hsl(210, 100%, 30%);

    --implicit-arg-text-color: var(--text-color);

    --def-color: #92dce5;
    --def-color-hsl-angle: 187;
    --theorem-color: #8fe388;
    --theorem-color-hsl-angle: 115;
    --axiom-and-constant-color: #f44708;
    --axiom-and-constant-color-hsl-angle: 16;
    --structure-and-inductive-color: #f0a202;
    --structure-and-inductive-color-hsl-angle: 40;
    --starting-percentage: 100;

    --hamburger-bg-color: #eee;
    --hamburger-active-color: white;
    --hamburger-border-color: #ccc;

    --tags-border-color: #555;

    --fragment-offset: calc(var(--header-height) + 1em);
    --content-width: 55vw;
}
/* automatic dark theme if no javascript */
@media (prefers-color-scheme: dark) {
    :root {
        --header-bg: #111010;
        --body-bg: #171717;
        --code-bg: #363333;
        --text-color: #eee;
        --link-color: #58a6ff;

        --implicit-arg-text-color: var(--text-color);

        --def-color: #1F497F;
        --def-color-hsl-angle: 214;
        --theorem-color: #134E2D;
        --theorem-color-hsl-angle: 146;
        --axiom-and-constant-color: #6B1B1A;
        --axiom-and-constant-color-hsl-angle: 1;
        --structure-and-inductive-color: #73461C;
        --structure-and-inductive-color-hsl-angle: 29;
        --starting-percentage: 30;

        --hamburger-bg-color: #2d2c2c;
        --hamburger-active-color: black;
        --hamburger-border-color: #717171;

        --tags-border-color: #AAA;
    }
}

[data-theme=\"light\"] {
    color-scheme: light;

    --header-height: 3em;
    --fragment-offset: calc(var(--header-height) + 1em);
    --content-width: 55vw;

    --header-bg: #f8f8f8;
    --body-bg: white;
    --code-bg: #f3f3f3;
    --text-color: black;
    --link-color: hsl(210, 100%, 30%);

    --implicit-arg-text-color: var(--text-color);

    --def-color: #92dce5;
    --def-color-hsl-angle: 187;
    --theorem-color: #8fe388;
    --theorem-color-hsl-angle: 115;
    --axiom-and-constant-color: #f44708;
    --axiom-and-constant-color-hsl-angle: 16;
    --structure-and-inductive-color: #f0a202;
    --structure-and-inductive-color-hsl-angle: 40;
    --starting-percentage: 100;

    --hamburger-bg-color: #eee;
    --hamburger-active-color: white;
    --hamburger-border-color: #ccc;

    --tags-border-color: #555;

    --fragment-offset: calc(var(--header-height) + 1em);
    --content-width: 55vw;
}

[data-theme=\"dark\"] {
    color-scheme: dark;

    --header-bg: #111010;
    --body-bg: #171717;
    --code-bg: #363333;
    --text-color: #eee;
    --link-color: #58a6ff;

    --implicit-arg-text-color: var(--text-color);

    --def-color: #1F497F;
    --def-color-hsl-angle: 214;
    --theorem-color: #134E2D;
    --theorem-color-hsl-angle: 146;
    --axiom-and-constant-color: #6B1B1A;
    --axiom-and-constant-color-hsl-angle: 1;
    --structure-and-inductive-color: #73461C;
    --structure-and-inductive-color-hsl-angle: 29;
    --starting-percentage: 30;

    --hamburger-bg-color: #2d2c2c;
    --hamburger-active-color: black;
    --hamburger-border-color: #717171;

    --tags-border-color: #AAA;
}

@supports (width: min(10px, 5vw)) {
    :root {
        --content-width: clamp(20em, 55vw, 60em);
    }
}

#nav_toggle {
    display: none;
}
label[for=\"nav_toggle\"] {
    display: none;
}

header {
    height: var(--header-height);
    float: left;
    position: fixed;
    width: 100vw;
    max-width: 100%;
    left: 0;
    right: 0;
    top: 0;
    --header-side-padding: 1em;
    padding: 0 var(--header-side-padding);
    background: var(--header-bg);
    z-index: 1;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

@media screen and (max-width: 1000px) {
    :root {
        --content-width: 100vw;
    }

    .internal_nav {
        display: none;
    }

    body .nav {
        width: 100vw;
        max-width: 100vw;
        margin-left: 1em;
        z-index: 1;
    }

    body main {
        width: unset;
        max-width: unset;
        margin-left: unset;
        margin-right: unset;
    }
    body .decl > div {
        overflow-x: unset;
    }

    #nav_toggle:not(:checked) ~ .nav {
        display: none;
    }
    #nav_toggle:checked ~ main {
        visibility: hidden;
    }

    label[for=\"nav_toggle\"]::before {
        content: '≡';
    }
    label[for=\"nav_toggle\"] {
        display: inline-block;
        margin-right: 1em;
        border: 1px solid var(--hamburger-border-color);
        padding: 0.5ex 1ex;
        cursor: pointer;
        background: var(--hamburger-bg-color);
    }
    #nav_toggle:checked ~ * label[for=\"nav_toggle\"] {
        background: var(--hamburger-active-color);
    }

    body header h1 {
        font-size: 100%;
    }

    header {
        --header-side-padding: 1ex;
    }
}
@media screen and (max-width: 700px) {
    header h1 span { display: none; }
    :root { --header-side-padding: 1ex; }
    #search_form button { display: none; }
    #search_form input { width: 100%; }
    header #autocomplete_results {
        left: 1ex;
        right: 1ex;
        width: inherit;
    }
    body header > * { margin: 0; }
}

header > * {
    display: inline-block;
    padding: 0;
    margin: 0;
    vertical-align: middle;
}

header h1 {
    font-weight: normal;
    font-size: 1.5em;
}

header .header_filename {
    font-size: 17px;
    color: gray;
    text-align: center;
    line-height: 95%;
}

/* inserted by nav.js */
#autocomplete_results {
    position: absolute;
    top: var(--header-height);
    right: calc(var(--header-side-padding));
    width: calc(20em + 4em);
    z-index: 1;
    background: var(--header-bg);
    border: 1px solid #aaa;
    border-top: none;
    overflow-x: hidden;
    overflow-y: auto;
    max-height: calc(100vh - var(--header-height));
}

#autocomplete_results:empty {
    display: none;
}

#autocomplete_results[state=\"loading\"]:empty {
    display: block;
    cursor: progress;
}
#autocomplete_results[state=\"loading\"]:empty::before {
    display: block;
    content: ' 🐙 🐙 🐙 🐙 🐙 🐙 🐙 🐙 🐙 🐙 🐙 🐙 🐙 🐙 🐙 ';
    padding: 1ex;
    animation: marquee 10s linear infinite;
}
@keyframes marquee {
    0% { transform: translate(100%, 0); }
    100% { transform: translate(-100%, 0); }
}

#autocomplete_results[state=\"done\"]:empty {
    display: block;
    text-align: center;
    padding: 1ex;
}
#autocomplete_results[state=\"done\"]:empty::before {
    content: '(no results)';
    font-style: italic;
}

#autocomplete_results a {
    display: block;
    color: inherit;
    padding: 1ex;
    border-left: 0.5ex solid transparent;
    padding-left: 0.5ex;
    cursor: pointer;
}

#autocomplete_results .selected .result_link a {
    background: var(--body-bg);
    border-color: var(--structure-and-inductive-color);
}


#search_results {
    width: 100%;
}
#search_results[state=\"done\"]:empty::before {
    content: '(no results)';
    font-style: italic;
}

#search_results .result_link, #search_results .result_doc {
    border-bottom: 1px solid rgba(0, 0, 0, 0.8);
}

.search_result_block {
    width: 100%;
    content-visibility: auto;
    contain-intrinsic-size: auto 75em;
}

.search_result_block_inner {
    display: table;
    width: 100%;
}

.search_result {
    display: table-row;
}

.result_link, .result_doc {
    display: table-cell;
    overflow: hidden;
    word-break: break-word;
}

main, nav {
    margin-top: calc(var(--header-height) + 1em);
}

/* extra space for scrolling things to the top */
main {
    margin-bottom: 90vh;
}

main {
    max-width: var(--content-width);
    /* center it: */
    margin-left: auto;
    margin-right: auto;
}

nav {
    float: left;
    height: calc(100vh - var(--header-height) - 1em);
    position: fixed;
    top: 0;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: transparent transparent;
}

nav:hover {
    scrollbar-color: gray transparent;
}

nav {
    --column-available-space: calc((100vw - var(--content-width) - 5em)/2);
    --column-width: calc(var(--column-available-space) - 1ex);
    --dist-to-edge: 1ex;
    width: var(--content-width);
    max-width: var(--column-width);
}
@supports (width: min(10px, 5vw)) {
    .nav { --desired-column-width: 20em; }
    .internal_nav { --desired-column-width: 30em; }
    nav {
        --column-available-space: calc(max(0px, (100vw - var(--content-width) - 5em)/2));
        --column-width: calc(clamp(0px, var(--column-available-space) - 1ex, var(--desired-column-width)));
        --dist-to-edge: calc(max(1ex, var(--column-available-space) - var(--column-width)));
    }
}

.nav { left: var(--dist-to-edge); }
.internal_nav { right: var(--dist-to-edge); }

.internal_nav .nav_link, .taclink {
    /* indent everything but first line by 2ex */
    text-indent: -2ex; padding-left: 2ex;
}

.navframe {
    height: 100%;
    width: 100%;
}

.navframe .nav {
    position: absolute;
    left: 0;
    margin-left: 0;
}

.internal_nav .imports {
    margin-bottom: 1rem;
}

.tagfilter-div {
    margin-bottom: 1em;
}
.tagfilter-div > summary {
    margin-bottom: 1ex;
}

/* top-level modules in left navbar */
.nav .module_list > details {
    margin-top: 1ex;
}

.nav details > * {
    padding-left: 2ex;
}

.nav summary {
    cursor: pointer;
    padding-left: 0;
}

.nav summary::marker {
    font-size: 85%;
}

.nav .nav_file {
    display: inline-block;
}

.nav h3 {
    margin-block-end: 4px;
}

/* People use way too long declaration names. */
.internal_nav, .decl_name {
    overflow-wrap: break-word;
}

/* Add a linebreak after a declaration name. */
.decl_name::after {
    content: \"\\A\";
    white-space: pre;
}

.nav_link {
    overflow-wrap: break-word;
}

.navframe {
    --header-height: 0;
}

#settings {
    margin-top: 5em;
}
#settings h3 {
    font-size: inherit;
}

#color-theme-switcher {
    display: flex;
    justify-content: space-between;
    padding: 0 2ex;
    flex-flow: row wrap;
}

/* custom radio buttons for dark/light switch */
#color-theme-switcher input {
    -webkit-appearance: none;
    -moz-appearance: none;
    appearance: none;
    display: inline-block;
    box-sizing: content-box;
    height: 1em;
    width: 1em;
    background-clip: content-box;
    padding: 2px;
    border: 2px solid transparent;
    margin-bottom: -4px;
    border-radius: 50%;
}
#color-theme-dark { background-color: #444; }
#color-theme-light { background-color: #ccc; }
#color-theme-system {
    background-image: linear-gradient(60deg, #444, #444 50%, #CCC 50%, #CCC);
}
#color-theme-switcher input:checked {
    border-color: var(--text-color);
}

.decl > div, .mod_doc {
    padding-left: 8px;
    padding-right: 8px;
}

.decl {
    margin-top: 20px;
    margin-bottom: 20px;
}

.decl > div {
    /* sometimes declarations arguments are way too long
       and would continue into the right column,
       so put a scroll bar there: */
    overflow-x: auto;
}

/* Make `#id` links appear below header. */
.decl, h1[id], h2[id], h3[id], h4[id], h5[id], h6[id] {
    scroll-margin-top: var(--fragment-offset);
}
/* don't need as much vertical space for these
inline elements */
a[id], li[id] {
    scroll-margin-top: var(--header-height);
}

/* HACK: Safari doesn't support scroll-margin-top for
fragment links (yet?)
https://caniuse.com/mdn-css_properties_scroll-margin-top
https://bugs.webkit.org/show_bug.cgi?id=189265
*/
@supports not (scroll-margin-top: var(--fragment-offset)) {
    .decl::before, h1[id]::before, h2[id]::before, h3[id]::before,
    h4[id]::before, h5[id]::before, h6[id]::before,
    a[id]::before, li[id]::before {
        content: \"\";
        display: block;
        height:      var(--fragment-offset);
        margin-top:  calc(-1 * var(--fragment-offset));
        box-sizing: inherit;
        visibility: hidden;
        width: 1px;
    }
}


/* hide # after markdown headings except on hover */
.markdown-heading:not(:hover) > .hover-link {
    visibility: hidden;
}

main h2, main h3, main h4, main h5, main h6 {
    margin-top: 1rem;
    margin-bottom: -0.4rem;
}
.decl + .mod_doc > h2,
        .decl + .mod_doc > h3,
        .decl + .mod_doc > h4,
        .decl + .mod_doc > h5,
        .decl + .mod_doc > h6 {
    margin-top: 4rem;
}

.def, .instance {
    border-left: 10px solid var(--text-color);
    border-top: 2px solid var(--text-color);
}

.theorem {
    border-left: 10px solid var(--theorem-color);
    border-top: 2px solid var(--theorem-color);
}

.axiom, .opaque {
    border-left: 10px solid var(--axiom-and-constant-color);
    border-top: 2px solid var(--axiom-and-constant-color);
}

.structure, .inductive, .class {
    border-left: 10px solid var(--structure-and-inductive-color);
    border-top: 2px solid var(--structure-and-inductive-color);
}

.fn {
    display: inline-block;
    /* border: 1px dashed red; */
    text-indent: -1ex;
    padding-left: 1ex;
    white-space: pre-wrap;
    vertical-align: top;
}

.fn { --fn: 1; }
.fn .fn { --fn: 2; }
.fn .fn .fn { --fn: 3; }
.fn .fn .fn .fn { --fn: 4; }
.fn .fn .fn .fn .fn { --fn: 5; }
.fn .fn .fn .fn .fn .fn { --fn: 6; }
.fn .fn .fn .fn .fn .fn .fn { --fn: 7; }
.fn .fn .fn .fn .fn .fn .fn .fn { --fn: 8; }
.fn {
    transition: background-color 100ms ease-in-out;
}

.def .fn:hover, .instance .fn:hover {
    background-color: hsla(var(--def-color-hsl-angle), 61%, calc(var(--starting-percentage) - 5%*var(--fn)));
    box-shadow: 0 0 0 1px hsla(var(--def-color-hsl-angle), 61%, calc(var(--starting-percentage) - 5%*(var(--fn) + 1)));
    border-radius: 5px;
}
.theorem .fn:hover {
    background-color: hsla(var(--theorem-color-hsl-angle), 62%, calc(var(--starting-percentage) - 5%*var(--fn)));
    box-shadow: 0 0 0 1px hsla(var(--theorem-color-hsl-angle), 62%, calc(var(--starting-percentage) - 5%*(var(--fn) + 1)));
    border-radius: 5px;
}
.axiom .fn:hover, .opaque .fn:hover {
    background-color: hsla(var(--axiom-and-constant-color-hsl-angle), 94%, calc(var(--starting-percentage) - 5%*var(--fn)));
    box-shadow: 0 0 0 1px hsla(var(--axiom-and-constant-color-hsl-angle), 94%, calc(var(--starting-percentage) - 5%*(var(--fn) + 1)));
    border-radius: 5px;
}
.structure .fn:hover, .inductive .fn:hover, .class .fn:hover {
    background-color: hsla(var(--structure-and-inductive-color-hsl-angle), 98%, calc(var(--starting-percentage) - 5%*var(--fn)));
    box-shadow: 0 0 0 1px hsla(var(--structure-and-inductive-color-hsl-angle), 98%, calc(var(--starting-percentage) - 5%*(var(--fn) + 1)));
    border-radius: 5px;
}

.decl_args, .decl_type .decl_parent {
    font-weight: normal;
}

.implicits, .impl_arg {
    color: var(--text-color);
    white-space: normal;
}

.decl_kind, .decl_name, .decl_extends {
    font-weight: bold;
}

/* break long declaration names at periods where possible */
.break_within {
    word-break: break-all;
}

.break_within .name {
    word-break: normal;
}

.decl_header {
    /* indent everything but first line twice as much as decl_type */
    text-indent: -8ex; padding-left: 8ex;
}

.decl_type {
    margin-top: 2px;
    margin-left: 4ex; /* extra indentation */
}

.decl.sorried .decl_name {
    text-decoration: underline wavy #cca733;
}

.decl .sorry_msg > strong {
    color: #a90000;
}

.imports li, code, .decl_header, .attributes, .structure_field_info,
        .constructor, .instances li, .instances-for-list li, .equation, .structure_ext_ctor {
    font-size: 92%;
    font-family: 'JuliaMono', monospace;
}

pre {
    white-space: break-spaces;
}

code, pre { background: var(--code-bg); }
code, pre { border-radius: 5px; }
code { padding: 1px 3px; }
pre { padding: 1ex; }
pre code { padding: 0 0; }

#howabout code { background: inherit; }
#howabout li { margin-bottom: 0.5ex; }

.structure_fields, .constructors {
    display: block;
    padding-inline-start: 0;
    margin-top: 1ex;
    text-indent: -2ex; padding-left: 2ex;
}

.structure_field {
    display: block;
    margin-left: 2ex;
}

.inductive_ctor_doc  {
    text-indent: 0;
    margin-left: 2ex;
    font-family: 'Lato Medium';
    font-size: 17px;
}

.structure_field_doc {
    text-indent: 0;
    font-family: 'Lato Medium';
    font-size: 17px;
}

.structure_ext_fields {
    display: block;
    padding-inline-start: 0;
    margin-top: 1ex;
    text-indent: -2ex; padding-left: 2ex;
}

.structure_ext_fields .structure_field {
    margin-left: -1ex !important;
}

.structure_ext_ctor {
    display: block;
    text-indent: -3ex;
}

.constructor {
    display: block;
}
.constructor:before {
    content: '| ';
    color: gray;
}

/** Don't show underline on types, to prevent the ≤ vs < confusion. **/
a:link, a:visited, a:active {
    color:var(--link-color);
    text-decoration: none;
}

/** Show it on hover though. **/
a:hover {
    text-decoration: underline;
}

.impl_arg {
    font-style: italic;
    transition: opacity 300ms ease-in;
}

.decl_header:not(:hover) .impl_arg,
        .constructor:not(:hover) .impl_arg,
        .structure_field_info:not(:hover) .impl_arg {
    opacity: 30%;
    transition: opacity 1000ms ease-out;
}

.inherited_field {
    transition: opacity 300ms ease-in;
}

.structure_fields:not(:hover) .inherited_field {
    opacity: 30%;
    transition: opacity 1000ms ease-out;
}

.gh_link {
    float: right;
    margin-left: 10px;
}

.ink_link {
    float: right;
    margin-left: 20px;
}


.docfile h2, .note h2 {
    margin-block-start: 3px;
    margin-block-end: 0px;
}

.docfile h2 a {
    color: var(--text-color);
}

.tags {
    margin-bottom: 1ex;
}

.tags ul {
    display: inline;
    padding: 0;
}

.tags li {
    border: 1px solid var(--tags-border-color);
    border-radius: 4px;
    list-style-type: none;
    padding: 1px 3px;
    margin-left: 1ex;
    display: inline-block;
}

/* used by nav.js */
.hide { display: none; }

.tactic, .note {
    border-top: 3px solid #0479c7;
    padding-top: 2em;
    margin-top: 2em;
    margin-bottom: 2em;
}
"

/-- Embedded from `assets/layouts/default.html`. -/
def defaultLayoutHtml : String := "<!-- LeanDoc's own minimal Jekyll layout (task T29, 2026-09-23).
     Needed because Jekyll only applies a layout's styling to a page
     when that page's front matter has `layout: <name>` — a plain
     `theme:`/`remote_theme:` in _config.yml is not, by itself,
     enough (confirmed against jekyllrb.com's own docs). LeanDoc's
     generated front matter now sets `layout: default`, so this file
     is what actually gets used.

     The #settings block + color-scheme.js (task T45) is adapted from
     doc-gen4's own light/dark/system theme switcher, simplified since
     LeanDoc has no separate nav-in-an-iframe document to coordinate
     with — see assets/color-scheme.js's own header comment.

     The #search block + search.js (task T47) is original, not adapted
     from doc-gen4 -- see assets/search.js's own header comment for why.
     LEANDOC_BASEURL is set here (not hardcoded in search.js) because
     only the layout goes through Liquid processing; search-index.json
     itself has no front matter, so it can't resolve
     {{ site.baseurl }} on its own.

     mathjax-config.js (task T51) must load *before* MathJax's own
     script, which reads window.MathJax at startup -- plain <script>,
     not type=\"module\", to guarantee that ordering (module scripts are
     deferred and don't reliably run before a later plain <script>). -->
<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>{{ page.title | default: site.title | default: \"LeanDoc\" }}</title>
  <link rel=\"stylesheet\" href=\"{{ '/assets/style.css' | relative_url }}\">
  <script>window.LEANDOC_BASEURL = \"{{ site.baseurl | default: '' }}\";</script>
  <script type=\"module\" src=\"{{ '/assets/color-scheme.js' | relative_url }}\"></script>
  <script type=\"module\" src=\"{{ '/assets/search.js' | relative_url }}\"></script>
  <script src=\"{{ '/assets/mathjax-config.js' | relative_url }}\"></script>
  <script id=\"MathJax-script\" async src=\"https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js\"></script>
  <style>
    #search { margin: 1em 0; }
    #search-results { list-style: none; padding: 0; margin: 0.5em 0 0; }
    #search-results li { padding: 0.15em 0; }
    .search-result-meta { opacity: 0.7; font-size: 0.9em; }
  </style>
</head>
<body>
  <div id=\"settings\" hidden>
    <form id=\"color-theme-switcher\">
      <label for=\"color-theme-dark\"><input type=\"radio\" name=\"color_theme\" id=\"color-theme-dark\" value=\"dark\" autocomplete=\"off\">dark</label>
      <label for=\"color-theme-system\" title=\"Match system theme settings\"><input type=\"radio\" name=\"color_theme\" id=\"color-theme-system\" value=\"system\" autocomplete=\"off\">system</label>
      <label for=\"color-theme-light\"><input type=\"radio\" name=\"color_theme\" id=\"color-theme-light\" value=\"light\" autocomplete=\"off\">light</label>
    </form>
  </div>
  <div id=\"search\">
    <input type=\"search\" id=\"search-input\" placeholder=\"Search declarations…\" autocomplete=\"off\">
    <ul id=\"search-results\"></ul>
  </div>
  <main>
    {{ content }}
  </main>
</body>
</html>
"

/-- Embedded from `assets/color-scheme.js`. -/
def colorSchemeJs : String := "/* Adapted from doc-gen4's color-scheme.js (task T45) -- simplified,
 * not vendored unmodified: doc-gen4 loads this inside an iframe (its
 * nav sidebar is a separate navbar.html document), so its original
 * uses `parent.document`/`parent.matchMedia` to reach back out to the
 * containing page. LeanDoc's layout is a single page with no iframe,
 * so this operates on `window`/`document` directly instead. Same core
 * logic otherwise: a `theme` preference (`system`/`light`/`dark`)
 * persisted in localStorage, applied via a `data-theme` attribute on
 * <html> that assets/style.css's [data-theme] rules key off of.
 *
 * Apache License, Version 2.0 (https://www.apache.org/licenses/LICENSE-2.0),
 * same license as LeanDoc itself. This is a modified derivative of
 * doc-gen4's file, not an unmodified copy like assets/style.css --
 * marked as changed here per the Apache-2.0 attribution requirement.
 * Original: https://github.com/leanprover/doc-gen4/blob/main/static/color-scheme.js
 */
function getTheme() {
  return localStorage.getItem(\"theme\") || \"system\";
}

function setTheme(themeName) {
  localStorage.setItem(\"theme\", themeName);
  if (themeName == \"system\") {
    themeName = window.matchMedia(\"(prefers-color-scheme: dark)\").matches ? \"dark\" : \"light\";
  }
  document.documentElement.setAttribute(\"data-theme\", themeName);
}

setTheme(getTheme());

document.addEventListener(\"DOMContentLoaded\", function () {
  document.querySelectorAll(\"#color-theme-switcher input\").forEach((input) => {
    if (input.value == getTheme()) {
      input.checked = true;
    }
    input.addEventListener(\"change\", (e) => setTheme(e.target.value));
  });

  // Also react if the user changes their OS-level theme settings while
  // the page is open and \"system\" is selected.
  window.matchMedia(\"(prefers-color-scheme: dark)\").addEventListener(\"change\", () => {
    setTheme(getTheme());
  });
});

// Un-hide the color-scheme picker once the script has actually run --
// keeps it invisible rather than broken for anyone without JavaScript.
document.querySelector(\"#settings\").removeAttribute(\"hidden\");
"

/-- Embedded from `assets/search.js`. -/
def searchJs : String := "/* Site-wide declaration index + client-side search (task T47).
 *
 * Fetches assets/search-index.json -- unlike the write-once assets
 * above (style.css, default.html, color-scheme.js), this file is
 * regenerated fresh by `render` on every `lake exe leandoc` run, since
 * it must reflect the project's current declarations, not a
 * one-time-written template.
 *
 * Simple case-insensitive substring matching against declaration
 * names, capped at 20 results -- no fuzzy/ranked matching. doc-gen4's
 * own client-side search is considerably more elaborate; LeanDoc's
 * typical (non-Mathlib) project scale doesn't need that yet, and a
 * naive substring match is easy to reason about and keep correct.
 *
 * Apache License, Version 2.0 (https://www.apache.org/licenses/LICENSE-2.0),
 * same license as LeanDoc itself. Original work, not adapted from
 * doc-gen4 (its declaration-data.js is tied to a much larger index
 * schema this doesn't attempt to match).
 */
(function () {
  const baseurl = window.LEANDOC_BASEURL || \"\";
  const input = document.querySelector(\"#search-input\");
  const results = document.querySelector(\"#search-results\");
  if (!input || !results) return;

  let index = null;
  fetch(baseurl + \"/assets/search-index.json\")
    .then((r) => r.json())
    .then((data) => {
      index = data;
    })
    .catch(() => {
      // No search-index.json (e.g. non-Jekyll output, or the file
      // genuinely failed to write) -- leave the box inert rather than
      // throwing in the console on every page load.
    });

  function renderResults(matches) {
    results.textContent = \"\";
    for (const d of matches) {
      const li = document.createElement(\"li\");
      const a = document.createElement(\"a\");
      a.href = baseurl + \"/\" + d.link;
      a.textContent = d.name;
      li.appendChild(a);
      const meta = document.createElement(\"span\");
      meta.className = \"search-result-meta\";
      meta.textContent = \" (\" + d.kind + \", \" + d.module + \")\";
      li.appendChild(meta);
      results.appendChild(li);
    }
  }

  input.addEventListener(\"input\", () => {
    const q = input.value.trim().toLowerCase();
    results.textContent = \"\";
    if (!index || q === \"\") return;
    const matches = index.filter((d) => d.name.toLowerCase().includes(q)).slice(0, 20);
    renderResults(matches);
  });
})();
"

/-- Embedded from `assets/mathjax-config.js`. -/
def mathjaxConfigJs : String := "/* MathJax configuration for rendering LaTeX in docstrings (task T51).
 *
 * Original, not vendored from doc-gen4 -- but matches its choice of
 * delimiters (`$...$` for inline math, `$$...$$` for display math),
 * so a docstring written with doc-gen4 in mind renders the same way
 * here. Loaded before MathJax's own script (see the layout), which
 * reads `window.MathJax` at startup.
 *
 * Apache License, Version 2.0 (https://www.apache.org/licenses/LICENSE-2.0),
 * same license as LeanDoc itself.
 */
window.MathJax = {
  tex: {
    inlineMath: [[\"$\", \"$\"]],
    displayMath: [[\"$$\", \"$$\"]],
  },
};
"

/-- Embedded from `assets/find.html`. -/
def findHtml : String := "<!DOCTYPE html>
<!--
  A stable permalink redirect (task T52): /find.html?pattern=<Name>
  looks the name up in assets/search-index.json (task T47) and
  redirects to its doc page, so an external link doesn't need to know
  which file a declaration lives in -- that can change (a module gets
  renamed/split) without breaking a link written against this page.

  Scoped to exact-name lookup only, redirecting to the doc page.
  Doc-gen4's own /find also supports a #src fragment redirecting to
  the declaration's *source* link instead of its doc page --
  search-index.json doesn't carry that (only the doc link), so this
  is deliberately left unimplemented rather than guessed at; the
  doc page itself already links to source (task T46) once there.

  Apache License, Version 2.0 (https://www.apache.org/licenses/LICENSE-2.0),
  same license as LeanDoc itself. Original, not adapted from doc-gen4.
-->
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
  <title>Find — LeanDoc</title>
</head>
<body>
  <p id=\"find-message\">Looking up declaration…</p>
  <script>
    (function () {
      var params = new URLSearchParams(window.location.search);
      var pattern = params.get(\"pattern\");
      var msg = document.getElementById(\"find-message\");
      if (!pattern) {
        msg.textContent = \"No pattern given -- use find.html?pattern=<DeclarationName>.\";
        return;
      }
      fetch(\"assets/search-index.json\")
        .then(function (r) { return r.json(); })
        .then(function (index) {
          var match = index.find(function (d) { return d.name === pattern; });
          if (match) {
            window.location.replace(match.link);
          } else {
            msg.textContent = \"No declaration named \\\"\" + pattern + \"\\\" found.\";
          }
        })
        .catch(function () {
          msg.textContent = \"Couldn't load the search index.\";
        });
    })();
  </script>
</body>
</html>
"

/-- Embedded from `assets/404.html`. -/
def notFoundHtml : String := "---
---
<!DOCTYPE html>
<!--
  A friendlier 404 page (task T53): when a link to a since-renamed or
  removed declaration's page breaks, suggest what the visitor probably
  meant instead of a bare \"not found\" -- GitHub Pages serves this file
  automatically for any unmatched path (jekyllrb.com/docs/github-pages
  / GitHub's own 404.html convention), so it needs no wiring beyond
  existing at docs_dir/404.html.

  Depends on assets/search-index.json (task T47) to have anything to
  suggest from -- Jekyll-only, same as find.html/search.js.

  This file gets minimal front matter (an empty \"---\\n---\\n\" block, no
  layout) purely so Jekyll runs Liquid over its own content -- unlike
  every other page here, a 404 page can be \"reached\" from a broken URL
  at ANY depth, so a relative asset/link path would break depending on
  where the visitor was trying to go. Resolving {{ site.baseurl }}
  directly, without a shared layout, sidesteps that: every path below
  is rooted from the site root instead of relative to the (unknown)
  broken URL's own depth.

  Matching is the same simple case-insensitive substring match as
  search.js (task T47), applied to the broken URL's last path
  segment -- not real fuzzy/edit-distance matching, consistent with
  T47's own scoping decision to keep this simple rather than pull in
  a matching library LeanDoc's typical project scale doesn't need.

  Apache License, Version 2.0 (https://www.apache.org/licenses/LICENSE-2.0),
  same license as LeanDoc itself. Original, not adapted from doc-gen4.
-->
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
  <title>Page not found — LeanDoc</title>
</head>
<body>
  <h1>Page not found</h1>
  <p>The page you were looking for doesn't exist — it may have been renamed or removed.</p>
  <div id=\"suggestions\"></div>
  <script>
    (function () {
      var baseurl = \"{{ site.baseurl | default: '' }}\";
      var segments = window.location.pathname.split(\"/\").filter(Boolean);
      var last = segments.pop() || \"\";
      var guess = last.replace(/\\.html?$/i, \"\");
      if (!guess) return;
      fetch(baseurl + \"/assets/search-index.json\")
        .then(function (r) { return r.json(); })
        .then(function (index) {
          var q = guess.toLowerCase();
          var matches = index
            .filter(function (d) { return d.name.toLowerCase().includes(q); })
            .slice(0, 10);
          if (matches.length === 0) return;
          var container = document.getElementById(\"suggestions\");
          var heading = document.createElement(\"p\");
          heading.textContent = \"Did you mean one of these?\";
          container.appendChild(heading);
          var list = document.createElement(\"ul\");
          matches.forEach(function (d) {
            var item = document.createElement(\"li\");
            var link = document.createElement(\"a\");
            link.href = baseurl + \"/\" + d.link;
            link.textContent = d.name;
            item.appendChild(link);
            list.appendChild(item);
          });
          container.appendChild(list);
        })
        .catch(function () {
          // No search index reachable -- leave the plain \"not found\"
          // message as-is rather than show a broken suggestions box.
        });
    })();
  </script>
</body>
</html>
"

end LeanDoc.Assets
