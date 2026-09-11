# VCF Insider

**Real Stories and Solutions from the Field**

VCF Insider is an independent technical site focused on real-world VMware
Cloud Foundation experience: upgrades, architecture, troubleshooting,
automation, networking, platform operations, and lessons learned in the field.

Live site:

https://www.vcfinsider.com/

Community:

https://community.vcfinsider.com/

## What You'll Find Here

VCF Insider is built around practical technical content rather than product
marketing.

Topics include:

- VMware Cloud Foundation architecture and operations
- VCF upgrades and lifecycle management
- NSX and networking
- AI and automation
- Troubleshooting and error handling
- VCF Automation and private-cloud consumption
- Field notes from real implementations
- Lessons learned from problems that did not go exactly as planned

The goal is simple: document useful technical experience in a way that helps
other people working with VCF.

## Site Structure

```text
_config.yml        Jekyll and site configuration
_layouts/          Page and article layouts
_includes/         Shared Liquid components
_pages/            Static pages
_posts/            Published articles
assets/css/        Site styling
assets/js/         Site JavaScript
assets/images/     Site and article images
index.html         Homepage
```

## Built With

The site currently uses:

- Jekyll
- GitHub Pages
- Minima
- Liquid templates
- Custom CSS and JavaScript
- jekyll-feed
- jekyll-sitemap
- jekyll-seo-tag

The production site uses the custom domain:

```text
https://www.vcfinsider.com
```

## Local Development

Prerequisites:

- Ruby 3.4+
- Bundler
- Git

Clone the repository:

```powershell
git clone https://github.com/krieg121/VCFInsider.git
cd VCFInsider
```

Install dependencies:

```powershell
bundle install
```

Build the site:

```powershell
bundle exec jekyll build
```

Serve it locally:

```powershell
bundle exec jekyll serve
```

Then open:

```text
http://127.0.0.1:4000/
```

For the full branch, preview, validation, and production deployment workflow,
see:

[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

## Publishing Articles

Articles are stored in:

```text
_posts/
```

Posts are Markdown files with Jekyll front matter describing things such as:

- title
- description
- excerpt
- publication date
- author
- category
- tags
- article and social images

The homepage automatically displays the four newest articles under
**Latest from the Field**, so new homepage cards do not need to be created
manually.

## Categories

The main site currently highlights:

- Cloud Foundation
- AI & Automation
- Security
- Networking

Additional article topics and category pages may exist as the content library
grows.

Visible category labels should preserve their authored capitalization,
spacing, acronyms, and punctuation.

## Community

VCF Insider also has a companion discussion community:

https://community.vcfinsider.com/

Articles may link directly to related community discussions so readers can
continue the conversation, share their own experience, or compare approaches.

The XenForo API and community automation workflow are documented separately in:

[XENFORO_API_RUNBOOK.md](XENFORO_API_RUNBOOK.md)

## Share Your Story

VCF Insider is not intended to be only one person's perspective.

If you have a useful VCF troubleshooting story, upgrade experience,
architecture lesson, automation workflow, or field note worth sharing, visit:

https://www.vcfinsider.com/share-your-story/

## Repository Workflow

`main` is the production branch.

Site changes are developed on focused test branches, reviewed and validated
locally, and merged into `main` only after production approval.

The detailed operating procedure is maintained in:

[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

## Contact

VCF Insider:

https://www.vcfinsider.com/contact/

GitHub:

https://github.com/krieg121

---

Built from real-world VCF experience and maintained as the working source for
VCF Insider.
