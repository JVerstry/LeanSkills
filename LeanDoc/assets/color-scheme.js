/* Adapted from doc-gen4's color-scheme.js (task T45) -- simplified,
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
  return localStorage.getItem("theme") || "system";
}

function setTheme(themeName) {
  localStorage.setItem("theme", themeName);
  if (themeName == "system") {
    themeName = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  document.documentElement.setAttribute("data-theme", themeName);
}

setTheme(getTheme());

document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll("#color-theme-switcher input").forEach((input) => {
    if (input.value == getTheme()) {
      input.checked = true;
    }
    input.addEventListener("change", (e) => setTheme(e.target.value));
  });

  // Also react if the user changes their OS-level theme settings while
  // the page is open and "system" is selected.
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    setTheme(getTheme());
  });
});

// Un-hide the color-scheme picker once the script has actually run --
// keeps it invisible rather than broken for anyone without JavaScript.
document.querySelector("#settings").removeAttribute("hidden");
