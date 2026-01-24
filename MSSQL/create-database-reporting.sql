-- ================================================================
-- TERMINOLOGY UPDATE REPORTING DATABASE SCHEMA
-- Target: Azure SQL Database (ReportingServer)
-- Server: azuresnnomedct.database.windows.net
-- ================================================================

-- ================================================================
-- CORE UPDATE TRACKING TABLES
-- ================================================================

-- Main update run tracking table
IF OBJECT_ID('dbo.update_runs', 'U') IS NULL
CREATE TABLE update_runs (
    run_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    start_time DATETIME2 NOT NULL,
    end_time DATETIME2 NULL,
    duration_seconds INT NULL,
    duration_formatted VARCHAR(20) NULL,
    success BIT NOT NULL DEFAULT 0,
    updates_found INT NOT NULL DEFAULT 0,
    server_name VARCHAR(255) NOT NULL,
    log_file_path NVARCHAR(500) NULL,
    config_path NVARCHAR(500) NULL,
    whatif_mode BIT NOT NULL DEFAULT 0,
    forced_run BIT NOT NULL DEFAULT 0,
    created_at DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_update_runs_start_time')
    CREATE INDEX IX_update_runs_start_time ON update_runs(start_time DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_update_runs_success')
    CREATE INDEX IX_update_runs_success ON update_runs(success);
GO

-- ================================================================
-- SNOMED CT TRACKING
-- ================================================================

IF OBJECT_ID('dbo.snomed_updates', 'U') IS NULL
CREATE TABLE snomed_updates (
    snomed_update_id INT IDENTITY(1,1) PRIMARY KEY,
    run_id UNIQUEIDENTIFIER NOT NULL,
    success BIT NOT NULL DEFAULT 0,
    new_release BIT NOT NULL DEFAULT 0,
    release_version VARCHAR(100) NULL,
    concept_count BIGINT NULL,
    description_count BIGINT NULL,
    relationship_count BIGINT NULL,
    langrefset_count BIGINT NULL,
    textdefinition_count BIGINT NULL,
    CONSTRAINT FK_snomed_updates_run FOREIGN KEY (run_id) REFERENCES update_runs(run_id)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_snomed_updates_run_id')
    CREATE INDEX IX_snomed_updates_run_id ON snomed_updates(run_id);
GO

-- ================================================================
-- DM+D TRACKING
-- ================================================================

IF OBJECT_ID('dbo.dmd_updates', 'U') IS NULL
CREATE TABLE dmd_updates (
    dmd_update_id INT IDENTITY(1,1) PRIMARY KEY,
    run_id UNIQUEIDENTIFIER NOT NULL,
    success BIT NOT NULL DEFAULT 0,
    new_release BIT NOT NULL DEFAULT 0,
    release_version VARCHAR(100) NULL,
    -- Current counts
    vtm_count INT NULL,
    vmp_count INT NULL,
    amp_count INT NULL,
    vmpp_count INT NULL,
    ampp_count INT NULL,
    ingredient_count INT NULL,
    lookup_count INT NULL,
    -- Change deltas from previous
    vtm_change INT NULL,
    vmp_change INT NULL,
    amp_change INT NULL,
    vmpp_change INT NULL,
    ampp_change INT NULL,
    -- Validation rates
    xml_validation_rate DECIMAL(5,2) NULL,
    snomed_validation_rate DECIMAL(5,2) NULL,
    CONSTRAINT FK_dmd_updates_run FOREIGN KEY (run_id) REFERENCES update_runs(run_id)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dmd_updates_run_id')
    CREATE INDEX IX_dmd_updates_run_id ON dmd_updates(run_id);
GO

-- ================================================================
-- STEP EXECUTION TRACKING
-- ================================================================

IF OBJECT_ID('dbo.update_steps', 'U') IS NULL
CREATE TABLE update_steps (
    step_id INT IDENTITY(1,1) PRIMARY KEY,
    run_id UNIQUEIDENTIFIER NOT NULL,
    terminology_type VARCHAR(20) NOT NULL,
    step_name NVARCHAR(100) NOT NULL,
    step_order INT NOT NULL,
    success BIT NOT NULL DEFAULT 0,
    details NVARCHAR(500) NULL,
    start_time DATETIME2 NULL,
    duration_seconds INT NULL,
    duration_formatted VARCHAR(10) NULL,
    CONSTRAINT FK_update_steps_run FOREIGN KEY (run_id) REFERENCES update_runs(run_id)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_update_steps_run_id')
    CREATE INDEX IX_update_steps_run_id ON update_steps(run_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_update_steps_terminology')
    CREATE INDEX IX_update_steps_terminology ON update_steps(terminology_type);
GO

-- ================================================================
-- ERROR TRACKING
-- ================================================================

IF OBJECT_ID('dbo.update_errors', 'U') IS NULL
CREATE TABLE update_errors (
    error_id INT IDENTITY(1,1) PRIMARY KEY,
    run_id UNIQUEIDENTIFIER NOT NULL,
    error_source VARCHAR(100) NULL,
    error_message NVARCHAR(MAX) NOT NULL,
    error_timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT FK_update_errors_run FOREIGN KEY (run_id) REFERENCES update_runs(run_id)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_update_errors_run_id')
    CREATE INDEX IX_update_errors_run_id ON update_errors(run_id);
GO

-- ================================================================
-- ONTOLOGY SERVER VALIDATION RESULTS
-- ================================================================

IF OBJECT_ID('dbo.ontology_validations', 'U') IS NULL
CREATE TABLE ontology_validations (
    validation_id INT IDENTITY(1,1) PRIMARY KEY,
    run_id UNIQUEIDENTIFIER NULL,
    validation_type VARCHAR(20) NOT NULL,
    total_tests INT NOT NULL DEFAULT 0,
    passed_tests INT NOT NULL DEFAULT 0,
    failed_tests INT NOT NULL DEFAULT 0,
    not_found_tests INT NOT NULL DEFAULT 0,
    partial_matches INT NOT NULL DEFAULT 0,
    validation_passed BIT NOT NULL DEFAULT 0,
    validation_timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT FK_ontology_validations_run FOREIGN KEY (run_id) REFERENCES update_runs(run_id)
);
GO

-- ================================================================
-- DMD IMPORT VALIDATION RESULTS
-- ================================================================

IF OBJECT_ID('dbo.dmd_import_validations', 'U') IS NULL
CREATE TABLE dmd_import_validations (
    import_validation_id INT IDENTITY(1,1) PRIMARY KEY,
    run_id UNIQUEIDENTIFIER NULL,
    integrity_issues INT NOT NULL DEFAULT 0,
    duplicate_issues INT NOT NULL DEFAULT 0,
    vtm_total_records INT NULL,
    vtm_active_records INT NULL,
    vtm_invalid_records INT NULL,
    vmp_total_records INT NULL,
    vmp_active_records INT NULL,
    vmp_invalid_records INT NULL,
    amp_total_records INT NULL,
    amp_active_records INT NULL,
    amp_invalid_records INT NULL,
    vmpp_total_records INT NULL,
    ampp_total_records INT NULL,
    validation_status VARCHAR(20) NOT NULL,
    report_file_path NVARCHAR(500) NULL,
    validation_timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT FK_dmd_import_validations_run FOREIGN KEY (run_id) REFERENCES update_runs(run_id)
);
GO

-- ================================================================
-- TRUD RELEASE TRACKING
-- ================================================================

IF OBJECT_ID('dbo.trud_releases', 'U') IS NULL
CREATE TABLE trud_releases (
    release_tracking_id INT IDENTITY(1,1) PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    trud_item_number INT NOT NULL,
    release_id VARCHAR(100) NOT NULL,
    release_date DATE NULL,
    detected_date DATETIME2 NOT NULL,
    downloaded_date DATETIME2 NULL,
    imported_date DATETIME2 NULL,
    import_success BIT NULL
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_trud_releases_item')
    CREATE INDEX IX_trud_releases_item ON trud_releases(item_name, release_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_trud_releases_detected')
    CREATE INDEX IX_trud_releases_detected ON trud_releases(detected_date DESC);
GO

-- ================================================================
-- NOTIFICATION TRACKING
-- ================================================================

IF OBJECT_ID('dbo.notifications_sent', 'U') IS NULL
CREATE TABLE notifications_sent (
    notification_id INT IDENTITY(1,1) PRIMARY KEY,
    run_id UNIQUEIDENTIFIER NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    recipients NVARCHAR(500) NOT NULL,
    subject NVARCHAR(500) NOT NULL,
    sent_success BIT NOT NULL DEFAULT 0,
    error_message NVARCHAR(MAX) NULL,
    sent_at DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT FK_notifications_sent_run FOREIGN KEY (run_id) REFERENCES update_runs(run_id)
);
GO

-- ================================================================
-- VIEWS FOR REPORTING / BLAZOR APP
-- ================================================================

-- Summary view for dashboard
IF OBJECT_ID('dbo.vw_update_summary', 'V') IS NOT NULL DROP VIEW vw_update_summary;
GO
CREATE VIEW vw_update_summary AS
SELECT 
    ur.run_id,
    ur.start_time,
    ur.end_time,
    ur.duration_formatted,
    ur.success AS overall_success,
    ur.updates_found,
    ur.server_name,
    ur.whatif_mode,
    su.success AS snomed_success,
    su.new_release AS snomed_new_release,
    su.release_version AS snomed_version,
    su.concept_count,
    su.description_count,
    du.success AS dmd_success,
    du.new_release AS dmd_new_release,
    du.release_version AS dmd_version,
    du.vmp_count,
    du.amp_count,
    du.xml_validation_rate,
    du.snomed_validation_rate,
    (SELECT COUNT(*) FROM update_errors e WHERE e.run_id = ur.run_id) AS error_count
FROM update_runs ur
LEFT JOIN snomed_updates su ON ur.run_id = su.run_id
LEFT JOIN dmd_updates du ON ur.run_id = du.run_id;
GO

-- Recent errors view
IF OBJECT_ID('dbo.vw_recent_errors', 'V') IS NOT NULL DROP VIEW vw_recent_errors;
GO
CREATE VIEW vw_recent_errors AS
SELECT TOP 100
    ur.run_id,
    ur.start_time,
    ur.server_name,
    ue.error_source,
    ue.error_message,
    ue.error_timestamp
FROM update_errors ue
INNER JOIN update_runs ur ON ue.run_id = ur.run_id
ORDER BY ue.error_timestamp DESC;
GO

-- Latest run status view
IF OBJECT_ID('dbo.vw_latest_run', 'V') IS NOT NULL DROP VIEW vw_latest_run;
GO
CREATE VIEW vw_latest_run AS
SELECT TOP 1 *
FROM vw_update_summary
ORDER BY start_time DESC;
GO

-- TRUD release history view
IF OBJECT_ID('dbo.vw_release_history', 'V') IS NOT NULL DROP VIEW vw_release_history;
GO
CREATE VIEW vw_release_history AS
SELECT 
    item_name,
    release_id,
    release_date,
    detected_date,
    downloaded_date,
    imported_date,
    import_success,
    CASE 
        WHEN imported_date IS NOT NULL AND import_success = 1 THEN 'Imported'
        WHEN downloaded_date IS NOT NULL THEN 'Downloaded'
        WHEN detected_date IS NOT NULL THEN 'Detected'
        ELSE 'Unknown'
    END AS status
FROM trud_releases;
GO

PRINT 'Terminology Reporting Database schema created successfully';
GO
