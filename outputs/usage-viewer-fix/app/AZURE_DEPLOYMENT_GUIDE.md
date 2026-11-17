# 🚀 Azure Static Web Apps Deployment Guide

## Your SNOMED CT Usage Data Viewer is Ready for Production!

This guide will walk you through deploying your Blazor WebAssembly application to Azure Static Web Apps.

## 📋 Prerequisites

- Azure account (free tier available)
- GitHub account
- Your repository pushed to GitHub

## 🌐 Deployment Steps

### Option 1: Automatic Deployment via Azure Portal (Recommended)

1. **Push to GitHub** (complete this first):
   ```powershell
   # If you haven't set up a GitHub repository yet:
   git remote add origin https://github.com/YOUR_USERNAME/StaticBlazorSnomed.git
   git branch -M main
   git push -u origin main
   ```

2. **Create Azure Static Web App**:
   - Go to [Azure Portal](https://portal.azure.com)
   - Click "Create a resource"
   - Search for "Static Web App"
   - Click "Create"

3. **Configure the Static Web App**:
   - **Subscription**: Select your Azure subscription
   - **Resource Group**: Create new or use existing
   - **Name**: `snomed-usage-viewer` (or your preferred name)
   - **Plan Type**: Free (for development) or Standard (for production)
   - **Region**: Choose closest to your users
   - **Source**: GitHub
   - **GitHub Account**: Sign in and authorize
   - **Organization**: Your GitHub username
   - **Repository**: `StaticBlazorSnomed`
   - **Branch**: `main` or `master`

4. **Build Configuration**:
   - **Build Presets**: Custom
   - **App location**: `/StaticBlazorSnomed`
   - **Api location**: (leave empty)
   - **Output location**: `wwwroot`

5. **Deploy**:
   - Click "Review + Create"
   - Click "Create"
   - Azure will automatically set up GitHub Actions for CI/CD

### Option 2: Manual Deployment via Azure CLI

```powershell
# Install Azure CLI if not already installed
# Download from: https://aka.ms/installazurecliwindows

# Login to Azure
az login

# Create resource group
az group create --name "rg-snomed-viewer" --location "East US"

# Create static web app
az staticwebapp create \
  --name "snomed-usage-viewer" \
  --resource-group "rg-snomed-viewer" \
  --source "https://github.com/YOUR_USERNAME/StaticBlazorSnomed" \
  --location "East US" \
  --branch "main" \
  --app-location "/StaticBlazorSnomed" \
  --output-location "wwwroot"
```

## 🔧 Configuration Details

### GitHub Actions Workflow
The deployment includes an automated GitHub Actions workflow that:
- Triggers on pushes to main/master branch
- Builds the Blazor WebAssembly application
- Deploys to Azure Static Web Apps
- Handles pull request previews

### Build Settings
```yaml
app_location: "/StaticBlazorSnomed"     # Root of your app
api_location: ""                        # No API (static only)
output_location: "wwwroot"              # Blazor output directory
app_build_command: "dotnet publish -c Release -o publish"
```

## 🌍 Post-Deployment

### 1. Custom Domain (Optional)
- In Azure Portal, go to your Static Web App
- Navigate to "Custom domains"
- Add your domain and configure DNS

### 2. Environment Variables
- Configure any environment-specific settings
- Update Azure Function URLs if needed

### 3. SSL Certificate
- Azure provides free SSL certificates
- Custom domains get automatic SSL

## 📊 Application Features

Your deployed application includes:

✅ **Primary Care SNOMED CT Usage Data Viewer**
- Professional interface matching original design
- Color-coded usage statistics (2011-2023)
- Interactive data table with sorting
- CSV export functionality

✅ **Search Capabilities**
- Basic SNOMED CT concept search
- Advanced search with filters
- Real-time results

✅ **Azure Integration**
- Connects to `snomed-viewer-function.azurewebsites.net`
- Fallback mock data for testing
- Connection diagnostics page

✅ **Performance Optimized**
- Blazor WebAssembly for fast loading
- Compressed assets (Brotli/GZip)
- Optimized for mobile and desktop

## 🔗 Sample URLs

After deployment, your application will be available at:
- Primary: `https://snomed-usage-viewer.azurestaticapps.net`
- Custom domain: `https://yourdomain.com` (if configured)

### Key Pages:
- **Home**: `/` - Usage Data Viewer
- **Search**: `/search` - SNOMED CT Search
- **Advanced Search**: `/advanced-search` - Advanced Filters
- **Connection Test**: `/test-connection` - API Diagnostics

## 🛠️ Troubleshooting

### Common Issues:

1. **Build Fails**:
   - Check GitHub Actions logs
   - Verify app_location path
   - Ensure .NET 8.0 compatibility

2. **App Won't Load**:
   - Check browser console for errors
   - Verify MIME types for .wasm files
   - Check network requests in dev tools

3. **API Connection Issues**:
   - Use `/test-connection` page to diagnose
   - Verify Azure Function URL
   - Check CORS settings

### Support Resources:
- [Azure Static Web Apps Documentation](https://docs.microsoft.com/en-us/azure/static-web-apps/)
- [Blazor WebAssembly Documentation](https://docs.microsoft.com/en-us/aspnet/core/blazor/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 🎉 Success!

Once deployed, your **SNOMED CT Usage Data Viewer** will be:
- ✅ Globally available via CDN
- ✅ Automatically SSL secured
- ✅ Continuously deployed from GitHub
- ✅ Scalable and performant
- ✅ Production-ready

**Next Step**: Push your code to GitHub and create the Azure Static Web App! 🚀
