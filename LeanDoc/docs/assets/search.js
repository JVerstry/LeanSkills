/* Site-wide declaration index + client-side search (task T47).
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
  const baseurl = window.LEANDOC_BASEURL || "";
  const input = document.querySelector("#search-input");
  const results = document.querySelector("#search-results");
  if (!input || !results) return;

  let index = null;
  fetch(baseurl + "/assets/search-index.json")
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
    results.textContent = "";
    for (const d of matches) {
      const li = document.createElement("li");
      const a = document.createElement("a");
      a.href = baseurl + "/" + d.link;
      a.textContent = d.name;
      li.appendChild(a);
      const meta = document.createElement("span");
      meta.className = "search-result-meta";
      meta.textContent = " (" + d.kind + ", " + d.module + ")";
      li.appendChild(meta);
      results.appendChild(li);
    }
  }

  input.addEventListener("input", () => {
    const q = input.value.trim().toLowerCase();
    results.textContent = "";
    if (!index || q === "") return;
    const matches = index.filter((d) => d.name.toLowerCase().includes(q)).slice(0, 20);
    renderResults(matches);
  });
})();
