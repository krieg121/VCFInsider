cat > _pages/categories.md <<'EOF'
---
layout: default
title: Categories
permalink: /categories/
---

<div class="container categories-wrapper">
  <h1 class="section-title">Browse by Category</h1>
  <p class="section-subtitle">Explore VCF Insider content by topic.</p>

  <div class="categories-grid">
    {%- assign cat_pages = site.pages | where_exp: "p", "p.layout == 'category'" | sort: "title" -%}
    {%- for p in cat_pages -%}
      <div class="category-card">
        <div class="category-icon icon-{{ p.class | default: 'generic' }}">
          {%- case p.class -%}
            {%- when 'cloud-foundation' -%}☁️
            {%- when 'networking' -%}🛜
            {%- when 'security' -%}🔒
            {%- else -%}📚
          {%- endcase -%}
        </div>
        <div class="category-title">{{ p.title }}</div>
        <div class="category-meta">
          {{ p.description | default: "Articles in this category" }}
        </div>
        <a class="category-btn" href="{{ p.permalink | relative_url }}">View posts</a>
      </div>
    {%- endfor -%}
  </div>
</div>
EOF
