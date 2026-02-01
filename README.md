# astradb-rest-schema-pipeline

A lightweight CI/CD solution for managing **AstraDB Enterprise (non-vector) schema changes** using versioned CQL files and GitHub
Actions.

This project provides a simple alternative to tools like Liquibase or Flyway by: 
- Running schema (DDL) scripts stored in the repository 
- Tracking which scripts have already been applied
- Ensuring scripts are not executed more than once
- Preventing modification of already-applied schema versions

Note: This repository manages **schema only (DDL)** --- it does NOT perform any data migration.

------------------------------------------------------------------------

## Features

-   Apply schema scripts in order (`V001__*.cql`, `V002__*.cql`, ...)
-   Uses only `curl` and AstraDB Stargate REST API
-   Maintains a schema history table (`schema_versions`)
-   Skips already-applied scripts
-   Fails if an applied script is modified (checksum validation)
-   Fully automated with GitHub Actions
-   Simple and transparent implementation

------------------------------------------------------------------------

## Repository Structure

    schema/
      V001__create_users_table.cql
      V002__alter_users_add_created_at.cql
      V003__alter_users_drop_created_at.cql

    scripts/
      apply-schema.sh

    .github/
      workflows/
        astradb-schema.yml

------------------------------------------------------------------------

## How It Works

1.  All schema changes are written as versioned CQL files in the
    `schema/` folder.
2.  The GitHub Actions workflow runs the script
    `scripts/apply-schema.sh`.
3.  The script:
    -   Creates a schema history table if it does not exist
    -   Reads all schema files in version order
    -   Checks if each version has already been applied
    -   Runs only new schema scripts
    -   Records execution metadata (version, checksum, timestamp,
        success)

If someone modifies a script that has already been applied, the pipeline
fails to protect schema integrity.

------------------------------------------------------------------------

## Schema History Table

``` sql
CREATE TABLE IF NOT EXISTS schema_versions (
  version text PRIMARY KEY,
  description text,
  script text,
  checksum text,
  applied_by text,
  applied_on timestamp,
  execution_time_ms int,
  success boolean
);
```

------------------------------------------------------------------------

## GitHub Actions Workflow

The workflow runs on: - Manual trigger (`workflow_dispatch`) - Push to
the `main` branch when schema files change

------------------------------------------------------------------------

## Required GitHub Secrets

|  Secret Name | Description |
| ------------- | ----------- |
| ASTRA_DB_ID   | AstraDB database ID |
| ASTRA_REGION  | Database region |
| ASTRA_TOKEN   | AstraDB application token |
| ASTRA_KEYSPACE| Target keyspace name |
------------------------------------------------------------------------

## Example Schema File

``` sql
ALTER TABLE users1 ADD created_at timestamp;
```

Naming convention:

    V<version>__<description>.cql

------------------------------------------------------------------------

## Rules & Best Practices

-   One DDL statement per file
-   Never modify a script that has already been applied
-   Always create a new version for new schema changes
-   Only DDL statements are allowed (CREATE, ALTER, DROP)
-   No INSERT, UPDATE, or DELETE statements

------------------------------------------------------------------------

## Why This Approach?

This project exists to: 
- Explore a curl-based approach using AstraDB REST APIs
- Avoid Java dependencies
- Keep full control of schema execution logic
- Demonstrate a minimal CI/CD pattern for AstraDB Enterprise

------------------------------------------------------------------------

## Limitations

-   Designed for AstraDB Enterprise (non-vector)
-   Does not support rollback
-   Requires schema scripts to be immutable
-   Assumes one statement per file

------------------------------------------------------------------------

## License

MIT License

------------------------------------------------------------------------

## Contributions

Pull requests and improvements are welcome. Please follow the versioned schema file naming convention.
```yaml
If you want, next I can generate for you:
- a **README.md file with badges (GitHub Actions status, license)**  
- a **Usage section (how to run locally)**  
- a **FAQ section**  
- or package this as a **zip-ready repo structure**

Just say which one:  
**badges**, **usage**, **FAQ**, or **zip repo**.
```