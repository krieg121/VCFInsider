---
layout: default
title: Categories
permalink: /categories/
---

<div class="container">
  <div class="section-header">
    <h2 class="section-title">Browse by Category</h2>
    <p class="section-subtitle">Pick a topic to see all related posts.</p>
  </div>

  {%- assign cat_pages = site.pages | where: "layout", "category" | sort: "title" -%}

  <div class="categories-grid">
    {%- for p in cat_pages -%}
      {%- assign key = p.category | default: p.title -%}
      {%- assign key_slug = key | slugify -%}

      {%- assign arr1 = site.categories[key] -%}
      {%- assign arr2 = site.categories[key_slug] -%}
      {%- assign arr3 = site.categories[p.title] -%}

      {%- assign count = 0 -%}
      {%- if arr1 -%}
        {%- assign count = arr1 | size -%}
      {%- elsif arr2 -%}
        {%- assign count = arr2 | size -%}
      {%- elsif arr3 -%}
        {%- assign count = arr3 | size -%}
      {%- endif -%}

      {%- assign accent = p.accent | default: '#0091DA' -%}

      <a class="category-card" href="{{ p.url | relative_url }}" style="--cat: {{ accent }}">
        {%- if p.icon_class and p.icon_class != '' -%}
          <i class="category-icon {{ p.icon_class }}"></i>
        {%- else -%}
          <i class="category-icon fa-solid fa-folder"></i>
        {%- endif -%}

        <div class="category-title">{{ p.title }}</div>
        {%- if p.description -%}<div class="category-meta">{{ p.description }}</div>{%- endif -%}
        <span class="category-btn">View posts</span>
      </a>
    {%- endfor -%}
  </div>
</div>
