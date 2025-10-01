---
layout: page
title: Categories
permalink: /categories/
---


<style>
.categories-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:1.5rem;margin:1.5rem 0}
.category-card{background:#fff;border-radius:10px;border:1px solid #e6e6e6;box-shadow:0 2px 4px rgba(0,0,0,.04);padding:0;transition:transform .1s ease,box-shadow .1s ease}
.category-card:hover{transform:translateY(-3px);box-shadow:0 6px 14px rgba(0,0,0,.08)}
/* Make the whole card a link */
.card-link{display:block;text-decoration:none;color:inherit;padding:1rem 1.25rem 1.25rem;border-radius:10px}
.card-link:focus-visible{outline:2px solid #0077C8;outline-offset:2px;border-radius:10px}
.category-header{border-top:8px solid var(--accent-color,#0077C8);margin:-1rem -1.25rem 1rem;padding:.75rem 1.25rem 0;border-radius:10px 10px 0 0}
.category-title{font-size:1.1rem;font-weight:600;color:#002856;margin:0;display:flex;align-items:center;gap:.5rem}
.category-desc{font-size:.95rem;margin:.25rem 0 .75rem;color:#333}
.category-footer{font-size:.85rem;font-weight:500;color:#0077C8}
</style>



<div class="categories-grid">
{%- assign category_pages = site.pages | where_exp: "p", "p.layout == 'category'" | sort: "title" -%}
{%- for p in category_pages -%}
  {%- assign cat_name = p.category | default: p.title -%}
  {%- assign count = site.categories[cat_name] | size -%}
  {%- assign icon = p.icon | default: "📂" -%}
  {%- assign accent_color = p.accent | default: "#333333" -%}

  <div class="category-card" style="--accent-color: {{ accent_color }}">
  <a class="card-link" href="{{ p.url | relative_url }}">
    <div class="category-header"></div>
    <h3 class="category-title">{{ icon }} {{ cat_name }}</h3>
    <p class="category-desc">{{ p.description | default: "Articles tagged “" | append: cat_name | append: "”." }}</p>
    <div class="category-footer">Browse → · {{ count | default: 0 }} posts</div>
  </a>
</div>

  
{%- endfor -%}
</div>

