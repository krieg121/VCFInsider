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
