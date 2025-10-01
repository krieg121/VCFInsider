---
layout: page
title: Categories
permalink: /categories/
---

<ul>
  {%- assign cats = site.categories | sort_natural: "first" -%}
  {%- if cats and cats.size > 0 -%}
    {%- for cat in cats -%}
      {%- assign cat_name = cat[0] -%}
      {%- assign cat_slug = cat_name | downcase | replace: ' ', '-' -%}
      <li>
        <a href="{{ '/categories/' | append: cat_slug | append: '/' | relative_url }}">
          {{ cat_name }} ({{ cat[1].size }})
        </a>
      </li>
    {%- endfor -%}
  {%- else -%}
    <li>No categories yet.</li>
  {%- endif -%}
</ul>
