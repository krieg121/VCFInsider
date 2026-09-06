// VCF Insider JavaScript
// This file can be expanded with interactive features later

console.log('VCF Insider site loaded successfully');

// Basic smooth scrolling for anchor links
document.addEventListener('DOMContentLoaded', function() {
    const navToggle = document.querySelector('.nav-toggle');
    const mainNav = document.getElementById('primary-navigation');

    if (navToggle && mainNav) {
        const closeNavigation = function() {
            navToggle.setAttribute('aria-expanded', 'false');
            navToggle.setAttribute('aria-label', 'Open navigation');
            mainNav.classList.remove('is-open');

            const icon = navToggle.querySelector('i');
            if (icon) {
                icon.classList.remove('fa-xmark');
                icon.classList.add('fa-bars');
            }
        };

        navToggle.setAttribute('aria-label', 'Open navigation');

        navToggle.addEventListener('click', function() {
            const isOpen = navToggle.getAttribute('aria-expanded') === 'true';

            if (isOpen) {
                closeNavigation();
                return;
            }

            navToggle.setAttribute('aria-expanded', 'true');
            navToggle.setAttribute('aria-label', 'Close navigation');
            mainNav.classList.add('is-open');

            const icon = navToggle.querySelector('i');
            if (icon) {
                icon.classList.remove('fa-bars');
                icon.classList.add('fa-xmark');
            }
        });

        mainNav.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', closeNavigation);
        });

        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeNavigation();
                navToggle.focus();
            }
        });

        window.addEventListener('resize', function() {
            if (window.innerWidth > 1024) {
                closeNavigation();
            }
        });
    }

    // Track clicks to the VCF Insider Community in Google Analytics.
    const communityLinks = document.querySelectorAll('a[href*="community.vcfinsider.com"]');
    communityLinks.forEach(link => {
        link.addEventListener('click', function() {
            if (typeof window.gtag !== 'function') {
                return;
            }

            const image = this.querySelector('img');
            const linkText = this.textContent.trim() || (image && image.alt) || 'VCF Insider Community';

            window.gtag('event', 'community_click', {
                link_url: this.href,
                link_text: linkText,
                link_location: this.dataset.communityLinkLocation || 'article-content',
                transport_type: 'beacon'
            });
        });
    });

    // Reveal homepage content as it enters the viewport.
    const revealSelector = [
        '.community-promo-inner',
        '.articles-section .section-header',
        '.articles-section .article-card',
        '.categories-section .section-header',
        '.categories-section .category-card--home'
    ].join(', ');

    const revealTargets = document.querySelectorAll(revealSelector);
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (revealTargets.length && !prefersReducedMotion && 'IntersectionObserver' in window) {
        document.documentElement.classList.add('motion-enabled');

        document.querySelectorAll('.articles-section .article-card').forEach((card, index) => {
            card.style.setProperty('--reveal-delay', `${Math.min(index, 5) * 70}ms`);
        });

        document.querySelectorAll('.categories-section .category-card--home').forEach((card, index) => {
            card.style.setProperty('--reveal-delay', `${index * 70}ms`);
        });

        const revealObserver = new IntersectionObserver(entries => {
            entries.forEach(entry => {
                if (!entry.isIntersecting) {
                    return;
                }

                entry.target.classList.add('is-visible');
                revealObserver.unobserve(entry.target);
            });
        }, {
            threshold: 0.12,
            rootMargin: '0px 0px -40px'
        });

        revealTargets.forEach(target => {
            target.classList.add('reveal-on-scroll');
            revealObserver.observe(target);
        });
    }

    // Show reading progress on article pages.
    const postContent = document.querySelector('.post-content');
    const postHeader = document.querySelector('.post-header');
    const siteHeader = document.querySelector('.site-header');

    if (postContent && siteHeader) {
        const progress = document.createElement('div');
        const progressBar = document.createElement('div');

        progress.className = 'reading-progress';
        progress.setAttribute('aria-hidden', 'true');
        progressBar.className = 'reading-progress-bar';
        progress.appendChild(progressBar);
        siteHeader.appendChild(progress);

        let progressUpdateQueued = false;

        const updateReadingProgress = function() {
            const startElement = postHeader || postContent;
            const articleStart = startElement.getBoundingClientRect().top + window.scrollY;
            const contentTop = postContent.getBoundingClientRect().top + window.scrollY;
            const articleEnd = contentTop + postContent.offsetHeight - window.innerHeight;
            const distance = Math.max(articleEnd - articleStart, 1);
            const amount = Math.min(Math.max((window.scrollY - articleStart) / distance, 0), 1);

            progressBar.style.transform = `scaleX(${amount})`;
            progressUpdateQueued = false;
        };

        const queueReadingProgressUpdate = function() {
            if (progressUpdateQueued) {
                return;
            }

            progressUpdateQueued = true;
            window.requestAnimationFrame(updateReadingProgress);
        };

        window.addEventListener('scroll', queueReadingProgressUpdate, { passive: true });
        window.addEventListener('resize', queueReadingProgressUpdate);
        updateReadingProgress();
    }

    // Add smooth scrolling to all anchor links
    const links = document.querySelectorAll('a[href^="#"]');
    links.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
});
