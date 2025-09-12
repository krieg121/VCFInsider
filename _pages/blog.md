---
layout: page
title: Blog
subtitle: Latest insights, tutorials, and best practices for VMware Cloud Foundation
permalink: /blog/
---

<div class="blog-content">
    <div class="blog-posts">
        {% for post in site.posts %}
        <article class="blog-post" style="display: flex; gap: 2rem; background: var(--vmware-white); border-radius: var(--border-radius-lg); overflow: hidden; box-shadow: var(--shadow-light); transition: var(--transition); border: 1px solid var(--border-light); margin-bottom: 2rem;">
            {% if post.featured_image %}
            <div class="post-image" style="flex: 0 0 300px; overflow: hidden;">
                <img src="{{ post.featured_image | relative_url }}" alt="{{ post.title | escape }}" style="width: 100%; height: 200px; object-fit: cover; transition: var(--transition);">
            </div>
            {% endif %}
            
            <div class="post-content" style="flex: 1; padding: 2rem; display: flex; flex-direction: column; justify-content: space-between;">
                <div>
                    <div class="post-meta" style="display: flex; gap: 1rem; margin-bottom: 1rem; font-size: 0.9rem; color: var(--text-muted);">
                        <span class="post-category" style="background: var(--vmware-orange); color: var(--vmware-white); padding: 0.25rem 0.75rem; border-radius: var(--border-radius); font-size: 0.8rem; font-weight: 600; text-transform: uppercase;">
                            {{ post.category | default: 'VCF Insights' }}
                        </span>
                        <time class="post-date" datetime="{{ post.date | date_to_xmlschema }}">
                            {{ post.date | date: "%B %d, %Y" }}
                        </time>
                        <span class="post-author">by {{ post.author | default: site.author.name }}</span>
                    </div>
                    
                    <h2 class="post-title" style="font-size: 1.5rem; font-weight: 600; margin-bottom: 1rem; line-height: 1.3;">
                        <a href="{{ post.url | relative_url }}" style="color: var(--text-primary); text-decoration: none; transition: var(--transition);">
                            {{ post.title | escape }}
                        </a>
                    </h2>
                    
                    <div class="post-excerpt" style="color: var(--text-secondary); line-height: 1.6; margin-bottom: 1.5rem;">
                        {{ post.excerpt | strip_html | truncate: 200 }}
                    </div>
                </div>
                
                <div class="post-actions" style="display: flex; justify-content: space-between; align-items: center;">
                    <a href="{{ post.url | relative_url }}" class="read-more" style="color: var(--vmware-blue); font-weight: 600; text-decoration: none; transition: var(--transition); display: inline-flex; align-items: center; gap: 0.5rem;">
                        Read Full Article <i class="fas fa-arrow-right"></i>
                    </a>
                    
                    {% if post.tags %}
                    <div class="post-tags" style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                        {% for tag in post.tags limit:3 %}
                        <span class="tag" style="background: var(--vmware-light-gray); color: var(--text-primary); padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.8rem;">
                            {{ tag }}
                        </span>
                        {% endfor %}
                    </div>
                    {% endif %}
                </div>
            </div>
        </article>
        {% endfor %}
    </div>
    
    {% if site.posts.size == 0 %}
    <div class="no-posts" style="text-align: center; padding: 4rem 2rem; color: var(--text-secondary);">
        <div style="font-size: 4rem; color: var(--vmware-blue); margin-bottom: 1rem;">
            <i class="fas fa-newspaper"></i>
        </div>
        <h3 style="font-size: 1.5rem; margin-bottom: 1rem; color: var(--vmware-blue);">No Posts Yet</h3>
        <p>We're working on bringing you the latest VCF insights. Check back soon!</p>
    </div>
    {% endif %}
</div>

<style>
.blog-post:hover {
    transform: translateY(-2px);
    box-shadow: var(--shadow-medium);
}

.blog-post:hover .post-image img {
    transform: scale(1.05);
}

.post-title a:hover {
    color: var(--vmware-blue);
}

.read-more:hover {
    color: var(--vmware-green);
}

@media (max-width: 768px) {
    .blog-post {
        flex-direction: column;
    }
    
    .post-image {
        flex: none;
    }
    
    .post-image img {
        height: 200px;
    }
    
    .post-content {
        padding: 1.5rem;
    }
    
    .post-actions {
        flex-direction: column;
        align-items: flex-start;
        gap: 1rem;
    }
}
</style>
