# API Testing with Newman and Postman

This document describes how API testing is integrated into the Salesforce CI/CD pipeline using [Newman](https://learning.postman.com/docs/collections/using-newman-cli/command-line-integration-with-newman/) and Postman collections.

## Overview

After every deployment to the destination org, the pipeline automatically runs API tests against the Salesforce REST APIs to validate that:

- The org is accessible and authenticated
- The deployed Apex classes (`HelloWorld`, `HelloWorldTest`) are active
- The Salesforce REST and Tooling APIs respond correctly
- Anonymous Apex execution works as expected

## Files

| File | Description |
|------|-------------|
| `postman-collection.json` | Postman collection with API test cases |
| `postman-environment.json` | Environment variable template |
| `.github/workflows/deploy-to-salesforce.yml` | CI/CD workflow including Newman step |

## API Test Cases

### Authentication
- **Verify Org Authentication** – Calls `/services/data/{{api_version}}/` and validates the identity, REST, and sobjects links are present.

### Apex REST (Tooling API – Execute Anonymous)
- **Execute HelloWorld greet via Anonymous Apex** – Runs `HelloWorld.greet('Salesforce')` and asserts execution succeeds without compile errors.
- **Execute HelloWorld greet with blank name** – Runs `HelloWorld.greet('')` and asserts successful execution.

### Tooling API
- **Verify HelloWorld Apex Class Exists** – Queries `ApexClass` for `HelloWorld` and asserts the record exists with `Status = Active`.
- **Verify HelloWorldTest Apex Class Exists** – Queries `ApexClass` for `HelloWorldTest` and asserts the record exists with `Status = Active`.

### REST API
- **List Available API Versions** – Calls `/services/data/` and validates the version list structure.
- **Query Account Object Metadata** – Calls `/services/data/{{api_version}}/sobjects/Account/` and checks the object is queryable.

## How to Run Tests Locally

### Prerequisites

```bash
npm install --global newman newman-reporter-htmlextra
```

### Set Environment Variables

Edit `postman-environment.json` and update:
- `org_url` – Your Salesforce org URL (e.g., `https://MyDomain.my.salesforce.com`)
- `access_token` – Your OAuth access token (obtain via `sf org display --json`)
- `api_version` – API version (default: `v52.0`, matches `sfdx-project.json`)

You can retrieve your org URL and access token using the Salesforce CLI:

```bash
sf org display --target-org <alias> --json
```

### Run the Collection

```bash
newman run postman-collection.json \
  --environment postman-environment.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman-reports/api-test-report.html
```

The HTML report will be saved to `newman-reports/api-test-report.html`.

## How to Export Collections from Postman

1. Open Postman and navigate to your collection.
2. Click the **⋯** (three dots) menu next to the collection name.
3. Select **Export**.
4. Choose **Collection v2.1** format.
5. Save the file as `postman-collection.json` in the repository root.

Similarly, to export an environment:
1. Go to **Environments** in the sidebar.
2. Click the **⋯** menu next to the environment.
3. Select **Export** and save as `postman-environment.json`.

## CI/CD Integration

The workflow step `Run API Tests with Newman` automatically:

1. Retrieves the org URL and access token from the authenticated Salesforce CLI session.
2. Overrides the environment variables `org_url` and `access_token` using `--env-var`.
3. Runs the full Postman collection and generates an HTML report.
4. Fails the workflow if any test assertions fail.

The HTML report is published as a GitHub Actions artifact named **api-test-reports** and is accessible from the workflow run summary page.

## Adding New Test Cases

To add new API tests:

1. Open `postman-collection.json` in Postman or a text editor.
2. Add a new request item inside the appropriate folder (e.g., `Tooling API`, `REST API`).
3. Add `pm.test(...)` assertions in the `event[listen=test]` script block.
4. Commit and push — the next workflow run will include the new tests.

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `org_url` | Salesforce org base URL | `https://MyDomain.my.salesforce.com` |
| `access_token` | OAuth 2.0 access token | *(set automatically in CI)* |
| `api_version` | REST API version | `v52.0` |
| `timeout` | Request timeout (ms) | `30000` |

> **Security note:** Never commit real access tokens to the repository. In CI the token is retrieved dynamically from the authenticated CLI session and masked in logs.
