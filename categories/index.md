---
layout: default
title: Categories
# When a file lives at categories/index.md, you can omit permalink,
# but keeping it is fine too:
permalink: /categories/
---

<div class="container categories-wrapper">
  <h1 class="section-title">Browse by Category</h1>
  <p class="section-subtitle">Explore VCF Insider content by topic.</p>

  {% comment %}
    Collect category pages from both normal pages and any collections (e.g., _pages)
  {% endcomment %}
  {% assign all_pages = site.pages | concat: site.documents %}
  {% assign cat_pages = all_pages | where_exp: "p", "p.layout == 'category'" | sort: "title" %}

  {% if cat_pages.size > 0 %}
    <div class="categories-grid">
      {% for p in cat_pages %}
        <div class="category-card {{ p.class | default: 'generic' }}">
          <div class="category-icon icon-{{ p.class | default: 'generic' }}">
            {% case p.class %}
              {% when 'cloud-foundation' %}☁️
              {% when 'networking' %}🛜
              {% when 'security' %}🔒
              {% when 'automation' %}🤖
              {% else %}📚
            {% endcase %}
          </div>
          <div class="category-title">{{ p.title }}</div>
          <div class="category-meta">{{ p.description | default: "Articles in this category" }}</div>
          <a class="category-btn" href="{{ p.permalink | relative_url }}">View posts</a>
        </div>
      {% endfor %}
    </div>
  {% else %}
    <div class="categories-grid">
      <div class="category-card {{ p.class | default: 'generic' }}">
        <div class="category-icon icon-cloud-foundation">☁️</div>
        <div class="category-title">Cloud Foundation</div>
        <div class="category-meta">VCF architecture, lifecycle, operations</div>
        <a class="category-btn" href="{{ '/categories/cloud-foundation/' | relative_url }}">View posts</a>
      </div>
      <div class="category-card {{ p.class | default: 'generic' }}">
        <div class="category-icon icon-networking">🛜</div>
        <div class="category-title">Networking</div>
        <div class="category-meta">NSX, segmentation, routing, load balancing</div>
        <a class="category-btn" href="{{ '/categories/networking/' | relative_url }}">View posts</a>
      </div>
      <div class="category-card {{ p.class | default: 'generic' }}">
        <div class="category-icon icon-security">🔒</div>
        <div class="category-title">Security</div>
        <div class="category-meta">Hardening, compliance, best practices</div>
        <a class="category-btn" href="{{ '/categories/security/' | relative_url }}">View posts</a>
      </div>
    </div>
  {% endif %}
</div>
