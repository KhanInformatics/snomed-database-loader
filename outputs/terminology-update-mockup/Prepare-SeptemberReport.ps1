# One-time migration of the real report supplied by the user, corroborated by
# C:\TerminologyLogs\WeeklyUpdate_20260905_120001.log. Counts/step times come from
# the email report. Overall 20:06 duration comes from the transcript's final summary
# (the email's 09:17 excluded reporting retries). No imports or emails are run.
$root='O:/GitHub/snomed-database-loader'
function Step($name,$duration) { @{Name=$name;Success=$true;Duration=$duration} }
$results=@{
    RunId='f8f3ae7b-5605-4a26-b9c4-202609051200'
    StartTime='2026-09-05T12:00:01+01:00'; EndTime='2026-09-05T12:20:07+01:00'
    Duration='00:20:06'; Success=$false; UpdatesFound=2; WhatIf=$false
    Errors=@('Azure SQL export failed: firewall blocked the scheduled machine.')
    SNOMED=@{Success=$true;NewRelease=$true;ReleaseVersion='42.5.0';ReleaseDate='2026-09-02';RowCounts=@{curr_concept_f=1152579;curr_description_f=3545886;curr_relationship_f=9740243;curr_langrefset_f=6827751};Steps=@((Step 'Check for new SNOMED release' '03:12'),(Step 'Import SNOMED to database' '02:25'),(Step 'Validate SNOMED import' '00:01'))}
    DMD=@{Success=$true;NewRelease=$true;TableCounts=@{amp=167099;vmp=24633;ampp=186902;vtm=3244;lookup=3861;ingredient=4569;vmpp=37344};TableChanges=@{vtm=2;vmp=13;amp=65;vmpp=15;ampp=82};Steps=@((Step 'Check for new DMD release' '00:30'),(Step 'Collect table statistics' '00:00'),(Step 'Validate DMD against XML' '00:04'),(Step 'Validate DMD against SNOMED CT' '01:18'))}
    DMWB=@{Success=$true;NewRelease=$false;Steps=@((Step 'Check for new DMWB release' '00:00'),(Step 'Skip' '00:00'))}
    PCD=@{Success=$true;RF2Status='Current';GPDataStatus='Current';GDPPRStatus='Current';LegacyStatus='N/A - not supplied in uk_sct2pc_63.0.0_20260717000000Z';TableCounts=@{GDPPR_Cluster_Refset=69584;GPData_Cluster_Refset=126144;Output_Descriptions_V2=0;Refset_Content_by_Output=111943;Refset_Content_V2=111943;Ruleset_Full_Name_Mappings_V2=0;Service_Full_Name_Mappings_V2=0};Steps=@((Step 'Validate current PCD RF2 snapshot' '00:07'),(Step 'Load current PCD supporting products' '01:03'),(Step 'Validate current PCD supporting products' '00:32'),(Step 'Inspect legacy PCD enrichment tables' '00:00'))}
}
& "$root/Export-ReportToGitHub.ps1" -Results $results -SaveOnly
