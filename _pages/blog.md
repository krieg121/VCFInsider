---
layout: page
title: Blog
subtitle: Latest insights, tutorials, and best practices for VMware Cloud Foundation
permalink: /blog/
body_class: blog-index
---

<div class="blog-posts">
  {% for post in site.posts %}
  {% assign card_image = post.featured_image | default: post.image %}
  <article class="blog-card{% if card_image %} blog-card--with-image{% endif %}">
    {% if card_image %}
    <div class="blog-card__image">
      <img src="{{ card_image | relative_url }}" alt="{{ post.title | escape }}" loading="lazy" decoding="async">
    </div>
    {% endif %}

    <div class="blog-card__content">
      <div class="blog-card__meta">
        {% include category_pill.html categories=post.categories preserve_label=true %}
        <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%B %d, %Y" }}</time>
        <span>by {{ post.author | default: site.author.name }}</span>
      </div>

      {% assign now = site.time | date: '%s' | plus: 0 %}
      {% assign then = post.date | date: '%s' | plus: 0 %}
      {% assign age = now | minus: then %}

      <h2 class="blog-card__title">
        <a href="{{ post.url | relative_url }}">{{ post.title | escape }}</a>
        {% if age < 604800 %}<span class="badge-new pulse">NEW</span>{% endif %}
      </h2>

      <div class="blog-card__excerpt">
        {{ post.excerpt | default: post.content | strip_html | truncate: 200 }}
      </div>

      <div class="blog-card__footer">
        {% if post.tags.size > 0 %}
        <div class="blog-card__tags">
          {% for tag in post.tags limit:3 %}
          <span class="blog-card__tag">{{ tag | escape }}</span>
          {% endfor %}
        </div>
        {% endif %}
        <a href="{{ post.url | relative_url }}" class="blog-card__read-more">
          Read Full Article <i class="fas fa-arrow-right" aria-hidden="true"></i>
        </a>
      </div>
    </div>
  </article>
  {% endfor %}
</div>

{% if site.posts.size == 0 %}
<div class="blog-empty">
  <i class="fas fa-newspaper blog-empty__icon" aria-hidden="true"></i>
  <h2>No Posts Yet</h2>
  <p>We're working on bringing you the latest VCF insights. Check back soon!</p>
</div>
{% endif %}
