---
layout: page
title: Categories
permalink: /categories/
---

<ul>
  {%- assign category_pages = site.pages | where_exp: "p", "p.layout == 'category'" | sort: "title" -%}
  {%- if category_pages and category_pages.size > 0 -%}
    {%- for p in category_pages -%}
      {%- assign cat_name = p.category | default: p.title -%}
      {%- assign count = site.categories[cat_name] | size -%}
      <li>
        <a href="{{ p.url | relative_url }}">{{ cat_name }}</a>
        {%- if count and count > 0 -%} ({{ count }}){%- endif -%}
      </li>
    {%- endfor -%}
  {%- else -%}
    <li>No category pages found.</li>
  {%- endif -%}
</ul>
