# GitHub Pages Setup Guide

This document describes how to configure and deploy the Heretek OpenClaw frontend to GitHub Pages.

## Overview

The frontend is built with Next.js and configured for static site export. It is deployed to GitHub Pages using GitHub Actions.

## Configuration

### 1. Repository Settings

1. Go to your repository on GitHub
2. Navigate to **Settings** > **Pages**
3. Under **Source**, select **GitHub Actions** (not "Deploy from a branch")

### 2. Environment Configuration

The GitHub Pages environment must be configured:

1. Go to **Settings** > **Environments**
2. Create a new environment named `github-pages`
3. No special configuration is needed for public repositories

### 3. Base Path Configuration

The application is configured with a base path in `frontend/next.config.mjs`:

```javascript
const nextConfig = {
  output: "export",
  basePath: "/heretek-openclaw",
  images: {
    unoptimized: true
  }
};
```

**Important:** If you change the repository name, update the `basePath` to match.

## Deployment Workflow

The deployment is handled by the `.github/workflows/frontend-cicd.yml` workflow:

1. **Trigger:** Push to `main` branch with changes in `frontend/` directory
2. **Build:** Next.js static export to `frontend/out`
3. **Deploy:** Upload to GitHub Pages

### Manual Deployment

To trigger a manual deployment:

1. Go to **Actions** > **Frontend CI/CD**
2. Click **Run workflow**
3. Select the `main` branch
4. Click **Run workflow**

## Directory Structure

```
frontend/
├── src/
│   ├── app/              # Next.js App Router pages
│   ├── components/       # Reusable React components
│   ├── lib/              # Utility functions
│   └── styles/           # Global styles
├── public/
│   └── json/             # Static JSON files
├── next.config.mjs       # Next.js configuration
├── package.json          # Dependencies and scripts
├── tailwind.config.ts    # Tailwind CSS configuration
└── tsconfig.json         # TypeScript configuration
```

## Local Development

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:3000 to view the development server.

## Building for Production

```bash
cd frontend
npm run build
```

The output will be in `frontend/out/`.

## Troubleshooting

### 404 Errors After Deployment

1. Check that `basePath` in `next.config.mjs` matches your repository name
2. Ensure the workflow completed successfully
3. Check the GitHub Pages environment configuration

### Build Failures

1. Check the Actions log for specific errors
2. Verify all dependencies are in `package.json`
3. Run `npm run build` locally to reproduce the issue

### Missing Assets

1. Ensure assets are in `frontend/public/`
2. Check that paths reference the correct base path
3. Verify the upload-pages-artifact step succeeded

## URL Structure

After deployment, the site will be available at:

```
https://{username}.github.io/{repository}/
```

For example:
```
https://heretek.github.io/heretek-openclaw/
```

## Custom Domain

To use a custom domain:

1. Add a `CNAME` file to the `frontend/public/` directory with your domain
2. Configure your DNS settings to point to GitHub Pages
3. Update the domain in **Settings** > **Pages** > **Custom domain**
