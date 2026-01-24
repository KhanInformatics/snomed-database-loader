// ============================================================
// TERMINOLOGY REPORTING API - Simple Example
// ============================================================
// This is a minimal ASP.NET Core Web API example showing how to
// expose the Azure SQL reporting data for a Blazor app.
//
// To use in your Blazor app:
// 1. Add these models and DbContext to your project
// 2. Register the DbContext in Program.cs
// 3. Add the controller or use minimal APIs
// ============================================================

// ------------------------------------------------------------
// FILE: Models/TerminologyModels.cs
// ------------------------------------------------------------

namespace TerminologyReporting.Models;

public class UpdateSummary
{
    public Guid RunId { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string? DurationFormatted { get; set; }
    public bool OverallSuccess { get; set; }
    public int UpdatesFound { get; set; }
    public string ServerName { get; set; } = string.Empty;
    public bool WhatIfMode { get; set; }
    
    // SNOMED
    public bool? SnomedSuccess { get; set; }
    public bool? SnomedNewRelease { get; set; }
    public string? SnomedVersion { get; set; }
    public long? ConceptCount { get; set; }
    public long? DescriptionCount { get; set; }
    
    // DMD
    public bool? DmdSuccess { get; set; }
    public bool? DmdNewRelease { get; set; }
    public string? DmdVersion { get; set; }
    public int? VmpCount { get; set; }
    public int? AmpCount { get; set; }
    public decimal? XmlValidationRate { get; set; }
    public decimal? SnomedValidationRate { get; set; }
    
    public int ErrorCount { get; set; }
}

public class UpdateRun
{
    public Guid RunId { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public int? DurationSeconds { get; set; }
    public string? DurationFormatted { get; set; }
    public bool Success { get; set; }
    public int UpdatesFound { get; set; }
    public string ServerName { get; set; } = string.Empty;
    public string? LogFilePath { get; set; }
    public bool WhatIfMode { get; set; }
    public bool ForcedRun { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class UpdateStep
{
    public int StepId { get; set; }
    public Guid RunId { get; set; }
    public string TerminologyType { get; set; } = string.Empty;
    public string StepName { get; set; } = string.Empty;
    public int StepOrder { get; set; }
    public bool Success { get; set; }
    public string? Details { get; set; }
    public DateTime? StartTime { get; set; }
    public int? DurationSeconds { get; set; }
    public string? DurationFormatted { get; set; }
}

public class UpdateError
{
    public int ErrorId { get; set; }
    public Guid RunId { get; set; }
    public string? ErrorSource { get; set; }
    public string ErrorMessage { get; set; } = string.Empty;
    public DateTime ErrorTimestamp { get; set; }
}

public class TrudRelease
{
    public int ReleaseTrackingId { get; set; }
    public string ItemName { get; set; } = string.Empty;
    public int TrudItemNumber { get; set; }
    public string ReleaseId { get; set; } = string.Empty;
    public DateTime? ReleaseDate { get; set; }
    public DateTime DetectedDate { get; set; }
    public DateTime? DownloadedDate { get; set; }
    public DateTime? ImportedDate { get; set; }
    public bool? ImportSuccess { get; set; }
}

// DTOs for API responses
public class DashboardDto
{
    public UpdateSummary? LatestRun { get; set; }
    public List<UpdateSummary> RecentRuns { get; set; } = new();
    public int TotalRuns { get; set; }
    public int SuccessfulRuns { get; set; }
    public int FailedRuns { get; set; }
    public DateTime? LastSuccessfulUpdate { get; set; }
}

public class RunDetailDto
{
    public UpdateRun Run { get; set; } = null!;
    public List<UpdateStep> Steps { get; set; } = new();
    public List<UpdateError> Errors { get; set; } = new();
}


// ------------------------------------------------------------
// FILE: Data/ReportingDbContext.cs
// ------------------------------------------------------------

using Microsoft.EntityFrameworkCore;

namespace TerminologyReporting.Data;

public class ReportingDbContext : DbContext
{
    public ReportingDbContext(DbContextOptions<ReportingDbContext> options) 
        : base(options) { }

    // Views (read-only)
    public DbSet<UpdateSummary> UpdateSummaries { get; set; }
    
    // Tables
    public DbSet<UpdateRun> UpdateRuns { get; set; }
    public DbSet<UpdateStep> UpdateSteps { get; set; }
    public DbSet<UpdateError> UpdateErrors { get; set; }
    public DbSet<TrudRelease> TrudReleases { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Map to view
        modelBuilder.Entity<UpdateSummary>(entity =>
        {
            entity.HasNoKey();
            entity.ToView("vw_update_summary");
            entity.Property(e => e.RunId).HasColumnName("run_id");
            entity.Property(e => e.StartTime).HasColumnName("start_time");
            entity.Property(e => e.EndTime).HasColumnName("end_time");
            entity.Property(e => e.DurationFormatted).HasColumnName("duration_formatted");
            entity.Property(e => e.OverallSuccess).HasColumnName("overall_success");
            entity.Property(e => e.UpdatesFound).HasColumnName("updates_found");
            entity.Property(e => e.ServerName).HasColumnName("server_name");
            entity.Property(e => e.WhatIfMode).HasColumnName("whatif_mode");
            entity.Property(e => e.SnomedSuccess).HasColumnName("snomed_success");
            entity.Property(e => e.SnomedNewRelease).HasColumnName("snomed_new_release");
            entity.Property(e => e.SnomedVersion).HasColumnName("snomed_version");
            entity.Property(e => e.ConceptCount).HasColumnName("concept_count");
            entity.Property(e => e.DescriptionCount).HasColumnName("description_count");
            entity.Property(e => e.DmdSuccess).HasColumnName("dmd_success");
            entity.Property(e => e.DmdNewRelease).HasColumnName("dmd_new_release");
            entity.Property(e => e.DmdVersion).HasColumnName("dmd_version");
            entity.Property(e => e.VmpCount).HasColumnName("vmp_count");
            entity.Property(e => e.AmpCount).HasColumnName("amp_count");
            entity.Property(e => e.XmlValidationRate).HasColumnName("xml_validation_rate");
            entity.Property(e => e.SnomedValidationRate).HasColumnName("snomed_validation_rate");
            entity.Property(e => e.ErrorCount).HasColumnName("error_count");
        });

        // Map tables
        modelBuilder.Entity<UpdateRun>(entity =>
        {
            entity.ToTable("update_runs");
            entity.HasKey(e => e.RunId);
            entity.Property(e => e.RunId).HasColumnName("run_id");
            entity.Property(e => e.StartTime).HasColumnName("start_time");
            entity.Property(e => e.EndTime).HasColumnName("end_time");
            entity.Property(e => e.DurationSeconds).HasColumnName("duration_seconds");
            entity.Property(e => e.DurationFormatted).HasColumnName("duration_formatted");
            entity.Property(e => e.Success).HasColumnName("success");
            entity.Property(e => e.UpdatesFound).HasColumnName("updates_found");
            entity.Property(e => e.ServerName).HasColumnName("server_name");
            entity.Property(e => e.LogFilePath).HasColumnName("log_file_path");
            entity.Property(e => e.WhatIfMode).HasColumnName("whatif_mode");
            entity.Property(e => e.ForcedRun).HasColumnName("forced_run");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
        });

        modelBuilder.Entity<UpdateStep>(entity =>
        {
            entity.ToTable("update_steps");
            entity.HasKey(e => e.StepId);
            entity.Property(e => e.StepId).HasColumnName("step_id");
            entity.Property(e => e.RunId).HasColumnName("run_id");
            entity.Property(e => e.TerminologyType).HasColumnName("terminology_type");
            entity.Property(e => e.StepName).HasColumnName("step_name");
            entity.Property(e => e.StepOrder).HasColumnName("step_order");
            entity.Property(e => e.Success).HasColumnName("success");
            entity.Property(e => e.Details).HasColumnName("details");
            entity.Property(e => e.StartTime).HasColumnName("start_time");
            entity.Property(e => e.DurationSeconds).HasColumnName("duration_seconds");
            entity.Property(e => e.DurationFormatted).HasColumnName("duration_formatted");
        });

        modelBuilder.Entity<UpdateError>(entity =>
        {
            entity.ToTable("update_errors");
            entity.HasKey(e => e.ErrorId);
            entity.Property(e => e.ErrorId).HasColumnName("error_id");
            entity.Property(e => e.RunId).HasColumnName("run_id");
            entity.Property(e => e.ErrorSource).HasColumnName("error_source");
            entity.Property(e => e.ErrorMessage).HasColumnName("error_message");
            entity.Property(e => e.ErrorTimestamp).HasColumnName("error_timestamp");
        });

        modelBuilder.Entity<TrudRelease>(entity =>
        {
            entity.ToTable("trud_releases");
            entity.HasKey(e => e.ReleaseTrackingId);
            entity.Property(e => e.ReleaseTrackingId).HasColumnName("release_tracking_id");
            entity.Property(e => e.ItemName).HasColumnName("item_name");
            entity.Property(e => e.TrudItemNumber).HasColumnName("trud_item_number");
            entity.Property(e => e.ReleaseId).HasColumnName("release_id");
            entity.Property(e => e.ReleaseDate).HasColumnName("release_date");
            entity.Property(e => e.DetectedDate).HasColumnName("detected_date");
            entity.Property(e => e.DownloadedDate).HasColumnName("downloaded_date");
            entity.Property(e => e.ImportedDate).HasColumnName("imported_date");
            entity.Property(e => e.ImportSuccess).HasColumnName("import_success");
        });
    }
}


// ------------------------------------------------------------
// FILE: Program.cs (Minimal API version)
// ------------------------------------------------------------

using Microsoft.EntityFrameworkCore;
using TerminologyReporting.Data;
using TerminologyReporting.Models;

var builder = WebApplication.CreateBuilder(args);

// Add DbContext with Azure AD authentication
builder.Services.AddDbContext<ReportingDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("ReportingDb"),
        sqlOptions => sqlOptions.EnableRetryOnFailure()
    ));

// Add CORS for Blazor WebAssembly
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();

// ============================================================
// API ENDPOINTS
// ============================================================

// GET /api/dashboard - Main dashboard data
app.MapGet("/api/dashboard", async (ReportingDbContext db) =>
{
    var summaries = await db.UpdateSummaries
        .OrderByDescending(s => s.StartTime)
        .Take(10)
        .ToListAsync();

    var totalRuns = await db.UpdateRuns.CountAsync();
    var successfulRuns = await db.UpdateRuns.CountAsync(r => r.Success);
    var lastSuccess = await db.UpdateRuns
        .Where(r => r.Success)
        .OrderByDescending(r => r.StartTime)
        .Select(r => r.StartTime)
        .FirstOrDefaultAsync();

    return Results.Ok(new DashboardDto
    {
        LatestRun = summaries.FirstOrDefault(),
        RecentRuns = summaries,
        TotalRuns = totalRuns,
        SuccessfulRuns = successfulRuns,
        FailedRuns = totalRuns - successfulRuns,
        LastSuccessfulUpdate = lastSuccess == default ? null : lastSuccess
    });
})
.WithName("GetDashboard")
.WithOpenApi();

// GET /api/runs - List all runs with pagination
app.MapGet("/api/runs", async (ReportingDbContext db, int page = 1, int pageSize = 20) =>
{
    var runs = await db.UpdateSummaries
        .OrderByDescending(s => s.StartTime)
        .Skip((page - 1) * pageSize)
        .Take(pageSize)
        .ToListAsync();

    var total = await db.UpdateRuns.CountAsync();

    return Results.Ok(new { runs, total, page, pageSize });
})
.WithName("GetRuns")
.WithOpenApi();

// GET /api/runs/{id} - Get run details with steps and errors
app.MapGet("/api/runs/{id:guid}", async (Guid id, ReportingDbContext db) =>
{
    var run = await db.UpdateRuns.FindAsync(id);
    if (run == null)
        return Results.NotFound();

    var steps = await db.UpdateSteps
        .Where(s => s.RunId == id)
        .OrderBy(s => s.TerminologyType)
        .ThenBy(s => s.StepOrder)
        .ToListAsync();

    var errors = await db.UpdateErrors
        .Where(e => e.RunId == id)
        .OrderBy(e => e.ErrorTimestamp)
        .ToListAsync();

    return Results.Ok(new RunDetailDto
    {
        Run = run,
        Steps = steps,
        Errors = errors
    });
})
.WithName("GetRunById")
.WithOpenApi();

// GET /api/latest - Get latest run summary only
app.MapGet("/api/latest", async (ReportingDbContext db) =>
{
    var latest = await db.UpdateSummaries
        .OrderByDescending(s => s.StartTime)
        .FirstOrDefaultAsync();

    return latest == null ? Results.NotFound() : Results.Ok(latest);
})
.WithName("GetLatestRun")
.WithOpenApi();

// GET /api/releases - Get TRUD release history
app.MapGet("/api/releases", async (ReportingDbContext db, string? itemName = null) =>
{
    var query = db.TrudReleases.AsQueryable();
    
    if (!string.IsNullOrEmpty(itemName))
        query = query.Where(r => r.ItemName == itemName);

    var releases = await query
        .OrderByDescending(r => r.DetectedDate)
        .Take(50)
        .ToListAsync();

    return Results.Ok(releases);
})
.WithName("GetReleases")
.WithOpenApi();

// GET /api/errors - Get recent errors
app.MapGet("/api/errors", async (ReportingDbContext db, int count = 20) =>
{
    var errors = await db.UpdateErrors
        .OrderByDescending(e => e.ErrorTimestamp)
        .Take(count)
        .ToListAsync();

    return Results.Ok(errors);
})
.WithName("GetErrors")
.WithOpenApi();

// GET /api/stats - Get overall statistics
app.MapGet("/api/stats", async (ReportingDbContext db) =>
{
    var stats = new
    {
        TotalRuns = await db.UpdateRuns.CountAsync(),
        SuccessfulRuns = await db.UpdateRuns.CountAsync(r => r.Success),
        FailedRuns = await db.UpdateRuns.CountAsync(r => !r.Success),
        TotalErrors = await db.UpdateErrors.CountAsync(),
        AverageValidationRate = await db.UpdateSummaries
            .Where(s => s.SnomedValidationRate != null)
            .AverageAsync(s => (double?)s.SnomedValidationRate) ?? 0,
        LastRun = await db.UpdateRuns
            .OrderByDescending(r => r.StartTime)
            .Select(r => r.StartTime)
            .FirstOrDefaultAsync()
    };

    return Results.Ok(stats);
})
.WithName("GetStats")
.WithOpenApi();

app.Run();


// ------------------------------------------------------------
// FILE: appsettings.json
// ------------------------------------------------------------
/*
{
  "ConnectionStrings": {
    "ReportingDb": "Server=tcp:azuresnnomedct.database.windows.net,1433;Initial Catalog=ReportingServer;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;Authentication=Active Directory Default"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
*/
