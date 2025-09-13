---
layout: page
title: Categories
permalink: /categories/
---

<ul class="categories-list">
  {% assign all_cats = "" | split: "" %}
  {% for post in site.posts %}
    {% for c in post.categories %}
      {% unless all_cats contains c %}
        {% assign all_cats = all_cats | push: c %}
      {% endunless %}
    {% endfor %}
  {% endfor %}
  {% assign all_cats = all_cats | sort %}

  {% for c in all_cats %}
    <li><a href="{{ '/categories/' | append: c | append: '/' | relative_url }}">{{ c }}</a></li>
  {% endfor %}
</ul>
