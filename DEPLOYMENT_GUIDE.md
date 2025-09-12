# VCF Insider - GitHub Pages Deployment Guide

## 🚀 Deploy Your VCF Insider Blog to GitHub Pages

Your Jekyll site is now ready for GitHub Pages! Follow these steps to deploy your blog and connect your custom domain.

## Step 1: Create GitHub Repository

1. **Go to GitHub.com** and sign in to your account
2. **Click "New repository"** (green button)
3. **Repository name**: `vcf-insider-blog` (or any name you prefer)
4. **Description**: "VCF Insider - VMware Cloud Foundation Blog"
5. **Make it Public** (required for free GitHub Pages)
6. **Don't initialize** with README (we have our own files)
7. **Click "Create repository"**

## Step 2: Upload Your Files to GitHub

### Option A: Using GitHub Desktop (Recommended for beginners)
1. **Download GitHub Desktop** from https://desktop.github.com/
2. **Clone your repository** to your computer
3. **Copy all your Jekyll files** into the repository folder
4. **Commit and push** your changes

### Option B: Using Git Command Line
```bash
# Navigate to your project directory
cd C:\Users\Chris\Documents\GitHub\wordpress-autopost

# Initialize git repository
git init

# Add all files
git add .

# Commit files
git commit -m "Initial commit - VCF Insider blog"

# Add your GitHub repository as remote
git remote add origin https://github.com/YOURUSERNAME/vcf-insider-blog.git

# Push to GitHub
git push -u origin main
```

## Step 3: Enable GitHub Pages

1. **Go to your repository** on GitHub.com
2. **Click "Settings"** tab
3. **Scroll down to "Pages"** section
4. **Source**: Select "Deploy from a branch"
5. **Branch**: Select "main" (or "master")
6. **Folder**: Select "/ (root)"
7. **Click "Save"**

## Step 4: Configure Custom Domain

### Update _config.yml for your GitHub Pages URL:
```yaml
# Change this line in _config.yml:
url: "https://YOURUSERNAME.github.io"
baseurl: "/vcf-insider-blog"  # Your repository name
```

### Add Custom Domain to GitHub Pages:
1. **In your repository Settings > Pages**
2. **Add your custom domain**: `vcfinsider.com`
3. **Check "Enforce HTTPS"** (will be available after DNS is configured)

## Step 5: Configure DNS (Domain Settings)

### Where to Make Changes:
- **Go to your domain registrar** (GoDaddy, Namecheap, etc.)
- **Find DNS management** or **DNS settings**

### DNS Records to Add:

#### For Root Domain (vcfinsider.com):
```
Type: A
Name: @
Value: 185.199.108.153
Value: 185.199.109.153
Value: 185.199.110.153
Value: 185.199.111.153
```

#### For WWW Subdomain (www.vcfinsider.com):
```
Type: CNAME
Name: www
Value: YOURUSERNAME.github.io
```

### Wait for DNS Propagation:
- **DNS changes** can take 24-48 hours to fully propagate
- **Use online tools** like https://dnschecker.org to verify

## Step 6: Verify Deployment

1. **Check GitHub Actions** tab in your repository for build status
2. **Visit your site**: `https://YOURUSERNAME.github.io/vcf-insider-blog`
3. **Test custom domain**: `https://vcfinsider.com` (after DNS propagation)
4. **Check HTTPS**: Ensure SSL certificate is working

## Troubleshooting

### Build Failures:
- **Check GitHub Actions** logs for error details
- **Verify Gemfile** has `github-pages` gem
- **Ensure _config.yml** has correct plugins

### DNS Issues:
- **Wait 24-48 hours** for full propagation
- **Use DNS checker** tools to verify
- **Check domain registrar** settings

### Custom Domain Not Working:
- **Verify DNS records** are correct
- **Wait for HTTPS** certificate (can take a few hours)
- **Check GitHub Pages** settings for domain configuration

## Post-Deployment Checklist

- ✅ **Site loads** at GitHub Pages URL
- ✅ **Custom domain** works (vcfinsider.com)
- ✅ **HTTPS** is enabled and working
- ✅ **All pages** load correctly
- ✅ **Blog posts** display properly
- ✅ **Contact form** works (if implemented)
- ✅ **RSS feed** is accessible

## Next Steps

1. **Add Google Analytics** for traffic monitoring
2. **Set up Google Search Console** for SEO
3. **Create social media** accounts
4. **Start promoting** your blog
5. **Regular content** publishing schedule

## Support

If you encounter issues:
1. **Check GitHub Pages** documentation
2. **Review Jekyll** troubleshooting guides
3. **Contact your domain registrar** for DNS issues

---

**Your VCF Insider blog will be live at: https://vcfinsider.com** 🎉
