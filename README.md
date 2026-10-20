<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Crowsnest icon">
</p>

<h1 align="center">Crowsnest</h1>

<p align="center">Watch your AWS CodePipeline deployments from the macOS menu bar.</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="docs/images/panel-light.png">
    <img src="docs/images/panel-dark.png" width="440" alt="Crowsnest panel showing a running build, a pending approval, a failed build, a rejected approval and a successful deployment">
  </picture>
</p>

## Features

- **Menu bar at a glance** — while a deployment runs, the menu bar shows the pipeline name with one bar per stage. When nothing is running it is just an icon.
- **Notifications that mean something** — you get notified when a deployment finishes (succeeded or failed) and when it starts waiting for a manual approval. An approval someone rejected on purpose is shown as **rejected**, not as a failure.
- **Why it failed, right there** — the failing action's error message and a link to its build log, without opening the console.
- **Zero setup** — uses the AWS profiles and SSO sessions already on your Mac. Profiles and pipelines are discovered automatically; nothing is hard-coded.
- **Light on battery** — polling calls the CodePipeline API directly instead of spawning `aws` processes, pauses while the screen is off or locked, slows down in Low Power Mode, and stops animations while the panel is closed.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="docs/images/menubar-light.png">
    <img src="docs/images/menubar-dark.png" width="440" alt="Menu bar states: running, waiting for approval, needs attention, idle">
  </picture>
</p>

| Menu bar | Meaning |
| --- | --- |
| Name + bars | A deployment is running. Solid bars are finished stages, the mid-tone bar is running, faint bars are still to come. |
| Hand + name + hollow bar | Waiting for a manual approval. |
| Icon with a dot | Something failed, or a pipeline could not be read (for example an expired SSO session). Open the panel for details. |
| Icon only | All quiet. |

## Requirements

- macOS 14 or later (Apple silicon)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) 2.9 or later — `brew install awscli`
- At least one profile set up with `aws configure` or `aws configure sso`
- Read-only permissions: `codepipeline:ListPipelines`, `codepipeline:GetPipelineState`, `codepipeline:ListPipelineExecutions`

## Install

### From a release

1. Download `Crowsnest-<version>.dmg` from [Releases](https://github.com/ldhbenecia/crowsnest/releases), open it and drag **Crowsnest** into **Applications**.
2. The app is not notarized (there is no Apple Developer account behind it), so macOS blocks the first launch. Either
   - right-click `Crowsnest.app` in Finder → **Open** → **Open**, or
   - remove the quarantine flag:

     ```bash
     xattr -dr com.apple.quarantine /Applications/Crowsnest.app
     ```

### From source

Only the Xcode Command Line Tools are needed.

```bash
git clone https://github.com/ldhbenecia/crowsnest.git
cd crowsnest
./script/build_and_run.sh --install
```

## Usage

1. Click the anchor icon in the menu bar, then **파이프라인 고르기** (pick pipelines) or the `+` button.
2. Pipelines are grouped by profile. Search and tick the ones you want to watch.
3. Click a row to expand every stage and action. Hover a row to reveal a button that opens it in the AWS console.

<p align="center">
  <img src="docs/images/picker.png" width="320" alt="Pipeline picker grouped by AWS profile">
</p>

Notifications can be turned off from the `···` menu in the panel header (**배포 알림**).

> The interface is currently in Korean.

## Configuration

`~/.config/crowsnest/config.json` is created with defaults on first launch. Restart the app after editing it (`···` → **설정 파일 열기** opens it).

| Key | Default | Description |
| --- | --- | --- |
| `defaultRegion` | `"ap-northeast-1"` | Region for profiles that have none in `aws configure` (e.g. SSO-only profiles). |
| `regionOverrides` | `{}` | Region per profile, e.g. `{"staging": "us-west-2"}`. |
| `hiddenProfiles` | `[]` | Profiles to leave out of the picker. |
| `awsCLIPath` | — | Path to the `aws` executable. When empty, `/opt/homebrew/bin`, `/usr/local/bin` and `/usr/bin` are searched. |
| `pollIntervalSeconds` | `30` | Refresh interval when nothing is running. |
| `activePollIntervalSeconds` | `10` | Refresh interval while a deployment is running. |

Intervals double in Low Power Mode. If every pipeline fails to load (offline, expired session), Crowsnest retries every 5 minutes until you press refresh.

## Troubleshooting

**"인증 만료 · 터미널에서 aws sso login --profile …"** (session expired)
Run the suggested `aws sso login` command, then press refresh (↻) in the panel. Without refresh it retries within 5 minutes.

**"aws CLI 를 못 찾음"** (aws CLI not found)
Install it with `brew install awscli`, or set `awsCLIPath` in `config.json` to the output of `which aws` and restart.

**A profile shows no pipelines**
Usually the region is wrong. Check `aws configure get region --profile <profile>` and set `regionOverrides` if needed.

**The menu bar icon is missing**
On Macs with a notch, menu bar items that do not fit are hidden. Remove some items, or ⌘-drag icons to reorder them.

**No notifications**
Check System Settings → Notifications → Crowsnest. Permission is requested on first launch.

**Logs**

```bash
log stream --info --predicate 'subsystem == "com.ldhbenecia.crowsnest"'
```

## Development

```bash
swift build                    # build
./script/test.sh               # tests (passes swift-testing paths when only Command Line Tools are installed)
./script/build_and_run.sh      # assemble the .app and launch it (--logs, --verify, --install)
./script/make_icon.sh          # redraw Resources/AppIcon.icns
./script/screenshots.sh        # regenerate the images in docs/images from sample data
```

### Releasing

The version lives in the `VERSION` file. The build writes it into `Info.plist` together with the commit hash and build date, which the About window shows.

```bash
echo 0.2.0 > VERSION && git commit -am "chore: 0.2.0"
git tag v0.2.0
./script/package.sh            # dist/Crowsnest-0.2.0.dmg and its sha256
gh release create v0.2.0 dist/Crowsnest-0.2.0.dmg
```

Builds are ad-hoc signed and not notarized.

## License

[MIT](LICENSE)
