/* MathJax configuration for rendering LaTeX in docstrings (task T51).
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
    inlineMath: [["$", "$"]],
    displayMath: [["$$", "$$"]],
  },
};
