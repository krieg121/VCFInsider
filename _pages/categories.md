---
layout: page
title: Categories
permalink: /categories/
---

<div class="categories-grid">
{%- assign category_pages = site.pages | where_exp: "p", "p.layout == 'category'" | sort: "title" -%}
{%- for p in category_pages -%}
  {%- assign cat_name     = p.category | default: p.title -%}
  {%- assign display_name = p.title    | default: cat_name -%}
  {%- assign count        = site.categories[cat_name] | size -%}

  {%- assign slug = cat_name
      | downcase
      | replace: ' & ', ' and '
      | replace: '&', 'and'
      | replace: ' / ', ' '
      | replace: '/', ' '
      | replace: '.', ''
      | replace: ' ', '-' -%}

  {%- assign icon   = p.icon   | default: '📂' -%}
  {%- assign accent = p.accent | default: '#0091DA' -%}

  <div class="category-card {{ slug }}" style="--cat: {{ accent | strip }}">
    <div class="category-icon">
      {%- if p.icon_class -%}
        <i class="{{ p.icon_class }}"></i>
      {%- else -%}
        {{ icon }}
      {%- endif -%}
    </div>
    <div class="category-title">{{ display_name }}</div>
    <div class="category-meta">{{ count | default: 0 }} posts</div>
    <a class="category-btn" href="{{ p.url | relative_url }}">Browse →</a>
  </div>
{%- endfor -%}
</div>
