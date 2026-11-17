"""Recreate READv2 database with case-sensitive collation."""
import pyodbc

conn = pyodbc.connect(
    r"DRIVER={ODBC Driver 17 for SQL Server};"
    r"SERVER=SilentPriory\SQLEXPRESS;DATABASE=master;"
    "Trusted_Connection=yes;TrustServerCertificate=yes;",
    autocommit=True,
)
cursor = conn.cursor()

# Kill existing connections to READv2
cursor.execute("""
    DECLARE @sql NVARCHAR(MAX) = '';
    SELECT @sql = @sql + 'KILL ' + CAST(session_id AS VARCHAR) + '; '
    FROM sys.dm_exec_sessions
    WHERE database_id = DB_ID('READv2') AND session_id != @@SPID;
    EXEC sp_executesql @sql;
""")

cursor.execute("DROP DATABASE IF EXISTS [READv2]")
print("Database dropped")

cursor.execute("CREATE DATABASE [READv2] COLLATE Latin1_General_CS_AS")
print("Database recreated with Latin1_General_CS_AS collation")

cursor.execute("SELECT DATABASEPROPERTYEX('READv2', 'Collation')")
print(f"Collation: {cursor.fetchone()[0]}")
conn.close()
