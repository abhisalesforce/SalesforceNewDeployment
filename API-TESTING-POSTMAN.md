# API Testing with Postman and Newman

Comprehensive guide for testing the **User API Service** and **Salesforce REST APIs** using Postman and Newman.

## Files

| File | Description |
|------|-------------|
| `postman-collection-api-tests.json` | Postman collection for User API Service with full CRUD operations |
| `postman-environment-setup.json` | Environment variable template (dev / staging / prod) |
| `postman-collection.json` | Postman collection for Salesforce REST API validation |
| `postman-environment.json` | Environment template for Salesforce REST API tests |
| `newman-run.sh` | Shell script to run tests via Newman CLI with reporting |
| `package.json` | NPM scripts for running tests |

---

## Prerequisites

### Install Newman

```bash
npm install --global newman newman-reporter-htmlextra
```

Or install locally via the project `package.json`:

```bash
npm install
```

### Verify installation

```bash
newman --version
```

---

## Manual Testing with Postman UI

### Import the collection

1. Open **Postman**.
2. Click **Import** (top left).
3. Select `postman-collection-api-tests.json`.
4. Click **Import**.

### Import the environment

1. Go to **Environments** in the left sidebar.
2. Click **Import**.
3. Select `postman-environment-setup.json`.
4. After importing, click the environment name and fill in:
   - `base_url` – Your API base URL (e.g. `https://MyDomain.my.salesforce.com`)
   - `access_token` – Your OAuth Bearer token
   - `client_id` / `client_secret` – For the token request (optional)

### Run the collection

1. Select the imported environment from the environment dropdown (top right).
2. In the left sidebar, click **Collections**.
3. Hover over **User API Service Tests** and click **▶ Run**.
4. In the Collection Runner, click **Run User API Service Tests**.

---

## Running Tests Locally via Newman CLI

### Basic run

```bash
newman run postman-collection-api-tests.json \
  --environment postman-environment-setup.json
```

### With HTML report

```bash
newman run postman-collection-api-tests.json \
  --environment postman-environment-setup.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman-reports/api-test-report.html \
  --timeout-request 30000
```

### Override environment variables inline

```bash
newman run postman-collection-api-tests.json \
  --environment postman-environment-setup.json \
  --env-var "base_url=https://MyDomain.my.salesforce.com" \
  --env-var "access_token=YOUR_TOKEN_HERE" \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman-reports/api-test-report.html
```

### Using the provided shell script

```bash
# Default (uses postman-collection-api-tests.json + postman-environment-setup.json)
bash newman-run.sh

# Override URLs and token via environment variables
BASE_URL=https://MyDomain.my.salesforce.com \
ACCESS_TOKEN=your_token \
bash newman-run.sh

# Custom collection and environment files
bash newman-run.sh \
  --collection postman-collection.json \
  --environment postman-environment.json \
  --output-dir newman-reports
```

### Using NPM scripts

```bash
# Run User API Service tests
npm run test:api

# Run Salesforce REST API tests
npm run test:api:sf

# Run via shell script (CI-friendly)
npm run test:api:ci

# Open the HTML report
npm run report:open
```

---

## Environment Configuration

Edit `postman-environment-setup.json` to configure the target environment.

| Variable | Description | Example |
|---|---|---|
| `environment` | Active environment label | `dev`, `staging`, `prod` |
| `base_url` | API base URL | `https://MyDomain.my.salesforce.com` |
| `auth_url` | OAuth token endpoint base | `https://login.salesforce.com` |
| `api_version` | User API version | `v1` |
| `access_token` | Bearer token | *(set dynamically or via CI secret)* |
| `client_id` | OAuth client ID | *(your Connected App key)* |
| `client_secret` | OAuth client secret | *(never commit real values)* |
| `created_user_id` | Auto-set by POST Create User | *(managed by pre-request/test scripts)* |
| `request_timeout` | Timeout per request (ms) | `30000` |

> **Security note:** Never commit real tokens, client secrets, or credentials to the repository.
> In CI, inject them via GitHub Actions secrets and pass them with `--env-var`.

---

## GitHub Actions Integration

The workflow in `.github/workflows/deploy-to-salesforce.yml` automatically:

1. Authenticates to the Salesforce org.
2. Deploys Apex classes.
3. Retrieves the org URL and access token.
4. Runs the Postman collection via Newman with `--env-var` overrides.
5. Uploads the HTML report as the `api-test-reports` artifact.

### Running API tests in a custom workflow step

```yaml
- name: Install Newman
  run: npm install --global newman newman-reporter-htmlextra

- name: Run User API Tests
  env:
    BASE_URL: ${{ secrets.API_BASE_URL }}
    ACCESS_TOKEN: ${{ secrets.API_ACCESS_TOKEN }}
  run: |
    mkdir -p newman-reports
    newman run postman-collection-api-tests.json \
      --environment postman-environment-setup.json \
      --env-var "base_url=$BASE_URL" \
      --env-var "access_token=$ACCESS_TOKEN" \
      --reporters cli,htmlextra \
      --reporter-htmlextra-export newman-reports/api-test-report.html \
      --timeout-request 30000

- name: Upload API Test Reports
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: api-test-reports
    path: newman-reports/
```

---

## Test Structure

### User API Service Tests (`postman-collection-api-tests.json`)

| Folder | Request | Description |
|---|---|---|
| Health Check | GET Health Status | Verifies the API is reachable |
| Users - CRUD | GET All Users | Lists all users; validates response structure |
| Users - CRUD | POST Create User | Creates a test user; saves ID dynamically |
| Users - CRUD | GET User by ID | Retrieves the created user by ID |
| Users - CRUD | PUT Update User | Updates the created user; verifies changes |
| Users - CRUD | DELETE User | Deletes the created user; cleans up variables |
| Users - Error Cases | GET User Not Found | Expects 404 for non-existent ID |
| Users - Error Cases | POST Create User - Missing Fields | Expects 400 validation error |
| Users - Error Cases | POST Create User - Unauthorized | Expects 401 with invalid token |
| Authentication | POST Obtain Access Token | Fetches and saves OAuth token |

### Dynamic Variable Flow

```
POST Create User
  └─ pre-request: generate test_username, test_email from timestamp
  └─ test script: save response.id → created_user_id

GET User by ID  ──uses──► created_user_id
PUT Update User ──uses──► created_user_id
DELETE User     ──uses──► created_user_id (then clears it)
```

---

## Interpreting Test Results

### CLI output

Newman prints a summary at the end of each run:

```
┌─────────────────────────┬──────────┬──────────┐
│                         │ executed │   failed │
├─────────────────────────┼──────────┼──────────┤
│              iterations │        1 │        0 │
│                requests │        9 │        0 │
│            test-scripts │       18 │        0 │
│      prerequest-scripts │        8 │        0 │
│              assertions │       30 │        0 │
├─────────────────────────┴──────────┴──────────┤
│ total run duration: 3.5s                       │
└────────────────────────────────────────────────┘
```

- **assertions failed = 0** → all tests passed ✅
- **assertions failed > 0** → review the failures listed above the summary ❌

### HTML report

Open `newman-reports/api-test-report.html` in a browser for a detailed, visual report including:
- Request/response bodies
- Assertion results per request
- Total pass/fail counts

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `newman: command not found` | Newman not installed | `npm install --global newman` |
| All tests fail with 401 | `access_token` is empty or expired | Set a valid token in the environment |
| `collection file not found` | Wrong working directory | Run commands from the repository root |
| `created_user_id` is empty on GET/PUT/DELETE | POST Create User was skipped or failed | Run the full collection in order |
| HTML report not generated | `newman-reporter-htmlextra` missing | `npm install --global newman-reporter-htmlextra` |
| 404 on GET All Users | `base_url` or `api_version` misconfigured | Verify environment variable values |

---

## Adding New Test Cases

1. Open `postman-collection-api-tests.json` in Postman or a text editor.
2. Add a new request inside the appropriate folder.
3. Add `pm.test(...)` assertions in the `event[listen=test]` script block.
4. Add any required setup in the `event[listen=prerequest]` script block.
5. Commit and push — the next workflow run will include the new tests.

Alternatively, create and export the request from the Postman UI, then commit the updated collection file.
