# JFrog bootstrap

**Experimental use only.** This entire project is for experimentation. Do not run any scripts or configuration in this repository against a production environment.

`scripts/bootstrap-jfrog.sh` provisions a JFrog project from a small JSON
file. You only name the project, the package types, and the lifecycle stages.
The script generates the repository layout, global stages, and an AppTrust
application. It is safe to run repeatedly: it creates only resources that are
absent and never updates or deletes existing resources.

## Prerequisites

- JFrog CLI (`jf`) configured with a default server, or a server ID supplied
  with `--server-id`.
- `jq` on `PATH`.
- Platform administrator permissions for projects, repositories, and global
  lifecycle stages. AppTrust application creation also requires AppTrust access
  to the referenced project.
- JFrog Platform 7.125.4 or newer for lifecycle-stage APIs.

The script uses the credentials, URL, and access token configured in the JFrog
CLI. Do not put these values in the desired-state file.

## Usage

Copy the example and replace its values:

```bash
vi scripts/jfrog-bootstrap.example.json scripts/jfrog-bootstrap.json

bash scripts/bootstrap-jfrog.sh --config scripts/jfrog-bootstrap.json --dry-run

bash scripts/bootstrap-jfrog.sh --config scripts/jfrog-bootstrap.json
```

Use a non-default CLI profile when needed:

```bash
bash scripts/bootstrap-jfrog.sh \
  --config scripts/jfrog-bootstrap.json \
  --server-id sandbox
```

`--dry-run` validates the config, reads the platform, and prints a plan. It
does not create resources and does not prompt.

A live run also prints that plan, then waits for confirmation
(`Apply this plan and create the missing resources? [y/N]`) before creating
anything. Answer `y` or `yes` to continue. Any other answer, or no answer,
aborts with no creates. Use `--yes` to skip the prompt (for automation). If every resource already exists, the
script exits after the plan and does not prompt.

Each run writes `logs/jfrog-bootstrap-YYYYMMDD-HHMMSS.log`. Every line has a
timestamp. The log includes the input file, the generated resource
configuration, each API request and response, and the JSON payload of every
create or associate call. The script also prints that generated configuration
on standard output before the plan. `logs/` is already ignored by git.

Artifactory reports a missing repository with HTTP 400 rather than 404. The
script treats both as "does not exist" and continues with create.

## Configuration format

Copy [`scripts/jfrog-bootstrap.example.json`](../scripts/jfrog-bootstrap.example.json):

```json
{
  "version": 1,
  "project": "frogs-us-rk",
  "repo_prefix": "frogs",
  "package_types": ["npm", "docker", "pypi", "helm"],
  "stages": ["DEV", "TEST", "QA", "PROD"],
  "app_trust": true,
  "app_name": "nodegoat",
  "app_owner": "team-frogs",
  "app_criticality": "high",
  "app_maturity": "production",
  "app_description": "NodeGoat is a vulnerable Node.js application that is used to test the security of Node.js applications.",
  "app_labels": {
    "lob": "finance",
    "compliance": "pci-dss"
  }
}
```

| Field | Required | Allowed input |
|---|---|---|
| `version` | Yes | `1` |
| `project` | Yes | JFrog project key and display name. 2–32 characters: a lowercase letter, then lowercase letters, digits, or hyphens. Example: `frogs-us-rk`. |
| `repo_prefix` | Yes | Repository name prefix only. Lowercase letters, digits, and hyphens, ending with a letter or digit. Example: `frogs`. |
| `package_types` | Yes | Non-empty array. Each value is one of `alpine`, `bower`, `cargo`, `chef`, `cocoapods`, `composer`, `conan`, `conda`, `debian`, `docker`, `gems`, `generic`, `go`, `gradle`, `helm`, `ivy`, `maven`, `npm`, `nuget`, `oci`, `pypi`, `sbt`, `terraform`, `yum`. `python` is accepted and treated as `pypi`. |
| `stages` | No | Array of stage names. Letters and digits; stored in uppercase. `DEV` is added when omitted because the virtual repository deploys to the DEV local. Example: `["DEV", "TEST", "QA", "PROD"]`. |
| `app_trust` | No | `true` creates or updates the AppTrust application. `false` or omitted skips every application call. |
| `app_name` | When `app_trust` is `true` | Application key and display name. 2–64 characters: a lowercase letter, then lowercase letters, digits, or hyphens. Example: `nodegoat`. |
| `app_owner` | No | Sent as `group_owners`. One existing project group name. Example: `team-frogs`. |
| `app_criticality` | No | `unspecified`, `low`, `medium`, `high`, or `critical`. |
| `app_maturity` | No | Sent as `maturity_level`. `unspecified`, `experimental`, `production`, or `end_of_life`. |
| `app_description` | No | Free-text application description. |
| `app_labels` | No | Object of label key/value pairs. Each key and value must start and end with a letter or digit. The characters allowed in between are letters, digits, `.`, `_`, and `-`. `@` is not allowed. Example: `{"lob": "finance", "compliance": "pci-dss"}`. |

The script generates repositories, stages, and the AppTrust request. Do not put repository JSON or credentials in this file.

## Generated layout

For each package type the script creates:

- one remote repository pointing at the public registry for that type
- one local repository per stage
- one virtual repository that includes every local plus the remote, with
  `defaultDeploymentRepo` set to the DEV local

Repository keys follow `{repo_prefix}-{packageType}-remote`,
`{repo_prefix}-{packageType}-{stage}-local`, and `{repo_prefix}-{packageType}`.
Repositories are created as platform repositories (no `projectKey`). After
every missing repository has been created, the script assigns each one to the
project with the [Move/Assign Repository](https://docs.jfrog.com/projects/reference/attachrepositorytoproject.md)
API.

It also creates:

- the JFrog project
- each named global lifecycle stage (create-only; reserved stages such as
  `PROD` that already exist are left unchanged)
- an AppTrust application from `app_name` when `app_trust` is `true`, skipped
  when the AppTrust readiness check returns HTTP 404 or 503

## Readiness checks

Before any resource is assessed, the script calls [Artifactory Ping](https://docs.jfrog.com/administration/reference/artifactoryping) (`GET /artifactory/api/system/ping`). A non-success response stops the run.

When `app_trust` is `true`, the script calls [AppTrust Ping](https://docs.jfrog.com/governance/reference/ping) (`GET /apptrust/api/v1/system/ping`). HTTP 200 continues. HTTP 404 or 503 skips application create and update. Any other AppTrust ping error stops the run.

## AppTrust availability

Authentication and authorization errors stop the run. They are not treated as an unavailable AppTrust service.

## Exit behavior

- `0`: the plan was applied, every resource already existed, or a dry-run
  completed.
- `1`: invalid input, missing prerequisites, a rejected plan, or a platform
  API failure. A rejected plan creates nothing. An API failure stops the run.

## Official API references

- [Artifactory Ping](https://docs.jfrog.com/administration/reference/artifactoryping)
- [AppTrust Ping](https://docs.jfrog.com/governance/reference/ping)
- [Move/Assign Repository to Project](https://docs.jfrog.com/projects/reference/attachrepositorytoproject.md)
- [Repository configuration APIs](https://docs.jfrog.com/artifactory/reference/getrepositoryconfiguration.md)
- [Create lifecycle stage](https://docs.jfrog.com/governance/reference/createlifecyclestage.md)
- [Get lifecycle stages](https://docs.jfrog.com/governance/reference/getlifecyclestages-1.md)
- [Create AppTrust application](https://docs.jfrog.com/governance/reference/createapplication.md)
- [Get AppTrust applications](https://docs.jfrog.com/governance/reference/getapplications.md)
