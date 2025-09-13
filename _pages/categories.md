---
layout: page
title: Categories
permalink: /categories/
---
<section class="categories-section" style="padding: 60px 0;">
  <div class="container">
    <div class="section-header">
      <h2 class="section-title">Explore by Category</h2>
      <p class="section-subtitle">Find content tailored to your VCF interests</p>
    </div>

    <div class="categories-grid" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:2rem;margin-top:2rem;">
      {% assign cats = "" | split: "" %}
      {% for post in site.posts %}
        {% for c in post.categories %}
          {% unless cats contains c %}
            {% assign cats = cats | push: c %}
          {% endunless %}
        {% endfor %}
      {% endfor %}
      {% assign cats = cats | sort %}
      {% for c in cats %}
        <div class="category-card" style="background:var(--vmware-light-gray);padding:1.75rem;border-radius:var(--border-radius-lg);text-align:center;">
          <h3 style="margin-bottom:.5rem">{{ c }}</h3>
          <a class="btn btn-primary" href="{{ '/categories/' | append: (c | slugify) | append: '/' | relative_url }}">Explore</a>
        </div>
      {% endfor %}
    </div>
  </div>
</section>
