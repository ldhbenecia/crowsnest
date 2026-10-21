# Security Policy

## Reporting a vulnerability

Please do not open a public issue. Report it privately through GitHub's [private vulnerability reporting](https://github.com/ldhbenecia/crowsnest/security/advisories/new) with steps to reproduce and the impact you expect. You will get a reply once it has been looked at.

Only the latest release receives security fixes.

## What Crowsnest handles

- **AWS credentials** — obtained with `aws configure export-credentials --profile <profile>` and kept in memory only, refreshed shortly before they expire. They are never written to disk, logs, or the config file.
- **Network** — signed requests go only to `https://codepipeline.<region>.amazonaws.com/`. The region is validated against the AWS region format before it is placed in the host name. If **Check for updates** is on, one unauthenticated request a day goes to `https://api.github.com/repos/ldhbenecia/crowsnest/releases/latest`; nothing about your AWS setup is sent.
- **aws CLI** — besides reading profiles and credentials, it runs `aws sso login` only when you press **Sign In**, and `aws configure set` only when you add a profile in Settings. Values typed into that form are checked against a strict format before they reach `~/.aws/config`.
- **Links it opens** — console links are built by the app on `console.aws.amazon.com`; build log links from the API are opened only if they are `http` or `https`. Release and bug report links are built by the app on `github.com`; a bug report pre-fills only the app and macOS versions.
- **Local files** — `~/.config/crowsnest/config.json` (regions, hidden profiles, refresh and notification preferences, no secrets) and the list of selected pipelines in `UserDefaults`.

Crowsnest only needs read access (`codepipeline:ListPipelines`, `codepipeline:GetPipelineState`, `codepipeline:ListPipelineExecutions`). It never approves, retries, or changes anything.
