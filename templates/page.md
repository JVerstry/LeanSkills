---
layout: default
title: My Guide
---

<!--
  Starter template for a hand-written page in your LeanDoc site (task
  T55). Copy it into your docs directory, for example:

    docs/guides/getting-started.md

  then rename, retitle and rewrite it. Keep the front matter block above
  as it is (change only the title): without `layout: default`, Jekyll
  serves the file as raw, unstyled Markdown.

  Put the page anywhere in your docs directory EXCEPT `reference/`,
  which LeanDoc deletes and regenerates on every run. Also avoid the
  file names LeanDoc writes itself: `toc.md`, `find.html`, `404.html`,
  and anything under `assets/` or `_layouts/`.

  This comment block isn't shown on the rendered page; delete it
  whenever you like. See "Adding your own pages" in LeanDoc's manual
  for the full walkthrough.
-->

# My Guide

A short introduction to what this page covers.

## Linking to generated documentation

These links work in any LeanDoc site:
[all modules]({% link reference/modules.md %}) and the
[table of contents]({% link toc.md %}).

To link one of your modules, use its dotted name as a path under
`reference/`, with a `.md` extension. For a module named
`MyProject.Basic` you would write:

{% raw %}
    [The MyProject.Basic module]({% link reference/MyProject/Basic.md %})
{% endraw %}

(That example is shown as text, not as a live link, on purpose: a
`link` tag pointing at a page that doesn't exist fails the whole site
build.)

## Linking to your other pages

[Back to the home page]({% link index.md %})

## Math

LaTeX renders here too: inline $a^2 + b^2 = c^2$, or display:

$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$
