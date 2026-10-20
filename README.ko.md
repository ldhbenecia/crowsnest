<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Crowsnest 아이콘">
</p>

<h1 align="center">Crowsnest</h1>

<p align="center">AWS CodePipeline 배포를 macOS 메뉴바에서 지켜보는 앱</p>

<p align="center"><a href="README.md">English</a> · <b>한국어</b></p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="docs/images/panel-light.png">
    <img src="docs/images/panel-dark.png" width="456" alt="진행 중 · 승인 대기 · 실패 · 반려 · 성공한 배포가 보이는 Crowsnest 패널">
  </picture>
</p>

> 스크린샷은 영어 화면임. 앱은 macOS 언어를 따라 한국어로도 나옴

## 기능

- **메뉴바에서 한눈에** — 배포가 돌고 있으면 파이프라인 이름과 스테이지마다 막대를 보여줌. 쉴 땐 아이콘만
- **꼭 필요한 알림만** — 배포가 끝나면(성공 · 실패) 그리고 수동 승인을 기다리기 시작하면 알림. 사람이 일부러 반려한 건 실패가 아니라 **반려됨** 으로 따로 보여줌
- **실패 이유를 바로** — 실패한 액션의 에러 메시지와 빌드 로그 링크를 콘솔을 안 열고 봄
- **설정할 게 없음** — 맥에 이미 있는 AWS 프로필 · SSO 세션을 그대로 씀. 프로필과 파이프라인을 자동으로 찾아서 따로 적을 게 없음
- **배터리를 거의 안 씀** — 폴링할 때 `aws` 프로세스를 띄우지 않고 CodePipeline API 를 직접 부름. 화면이 꺼지거나 잠기면 멈추고, 저전력 모드면 천천히, 패널이 닫혀 있으면 애니메이션도 멈춤

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="docs/images/menubar-light.png">
    <img src="docs/images/menubar-dark.png" width="452" alt="메뉴바 상태: 진행 중, 승인 대기, 확인 필요, 쉬는 중">
  </picture>
</p>

| 메뉴바 | 뜻 |
| --- | --- |
| 이름 + 막대 | 배포 중. 진한 칸은 끝난 스테이지, 중간 칸은 도는 중, 옅은 칸은 남은 스테이지 |
| 손 + 이름 + 속 빈 칸 | 수동 승인을 기다리는 중 |
| 아이콘 + 점 | 실패했거나 조회가 안 됨(SSO 세션 만료 등). 패널을 열어서 확인 |
| 아이콘만 | 문제 없음 |

## 준비물

- macOS 14 이상 (Apple 실리콘)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) 2.9 이상 — `brew install awscli`
- `aws configure` 또는 `aws configure sso` 로 등록한 프로필 하나 이상
- 읽기 권한: `codepipeline:ListPipelines` · `codepipeline:GetPipelineState` · `codepipeline:ListPipelineExecutions`

## 설치

### 릴리스에서 받기

1. [Releases](https://github.com/ldhbenecia/crowsnest/releases) 에서 `Crowsnest-<버전>.dmg` 를 받아 열고 **Crowsnest** 를 **Applications** 로 끌어다 놓기
2. 터미널에서 한 번 실행:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Crowsnest.app
   ```

3. 응용 프로그램에서 **Crowsnest** 를 열면 메뉴바에 닻 아이콘이 생김

#### 2번 명령어가 왜 필요하냐면

Crowsnest 는 ad-hoc 서명만 하고 Apple 공증은 받지 않았음(유료 Apple 개발자 계정이 없어서). 2번을 건너뛰면 처음 열 때 이런 창이 뜨고 안 열림:

<p align="center">
  <img src="docs/images/gatekeeper-warning.png" width="372" alt="macOS 경고: Apple은 Crowsnest.app에 악성 코드가 없음을 확인할 수 없습니다. 휴지통으로 이동 · 완료 버튼">
</p>

Apple 이 앱을 검사하지 않았다는 뜻이지 뭔가가 발견됐다는 뜻은 아님. **완료** 를 누르고(**휴지통으로 이동** 말고) 2번 명령어를 실행한 뒤 다시 열면 됨. 명령어 대신 **시스템 설정 → 개인정보 보호 및 보안** 맨 아래의 **그래도 열기** 를 눌러도 됨. macOS 15 부터는 우클릭 → 열기로는 이 창을 넘길 수 없음

새 버전을 받으면 다시 막히니 업데이트할 때마다 2번을 한 번 더 실행

### 소스에서 빌드

Xcode 없이 Command Line Tools 만 있으면 됨

```bash
git clone https://github.com/ldhbenecia/crowsnest.git
cd crowsnest
./script/build_and_run.sh --install
```

## 사용법

1. 메뉴바의 닻 아이콘을 누르고 **파이프라인 고르기** 또는 `+` 버튼
2. 프로필별로 묶인 목록에서 검색하고 지켜볼 파이프라인을 체크
3. 행을 누르면 스테이지 · 액션을 다 펼쳐서 보여줌. 행에 마우스를 올리면 AWS 콘솔로 가는 버튼이 나옴

<p align="center">
  <img src="docs/images/picker.png" width="336" alt="AWS 프로필별로 묶인 파이프라인 선택 화면">
</p>

화면 언어는 한국어 · 영어. 기본은 macOS 언어를 따르고 **설정 → 일반 → 언어** 에서 바꿀 수 있음

## 설정

패널 오른쪽 위 `···` 메뉴의 **설정…**, 또는 패널이 열려 있을 때 ⌘, 로 열림. 바꾸면 바로 반영됨

<p align="center">
  <img src="docs/images/settings-general.png" width="556" alt="일반 설정: 언어, 로그인 시 자동 실행, 갱신 주기">
</p>

<p align="center">
  <img src="docs/images/settings-aws.png" width="556" alt="AWS 설정: aws CLI 경로, 기본 리전, 프로필별 보이기와 리전">
</p>

- **일반** — 언어, 로그인할 때 자동 실행, 쉴 때 · 배포 중일 때 갱신 주기, 저전력 모드에서 천천히
- **알림** — 종류별로 켜고 끄기(성공 · 실패와 중지 · 승인 필요 · 반려), 소리
- **AWS** — 쓰는 `aws` 실행 파일, 기본 리전, 프로필마다 보일지와 쓸 리전

모든 설정은 `~/.config/crowsnest/config.json` 에 저장돼서 dotfiles 로 관리해도 됨. 파일을 직접 고치면 다음 실행 때 반영됨

| 키 | 기본값 | 설명 |
| --- | --- | --- |
| `defaultRegion` | `"ap-northeast-1"` | `aws configure` 에 리전이 없는 프로필(SSO 전용 등)에 쓸 리전 |
| `regionOverrides` | `{}` | 프로필별 리전. 예: `{"staging": "us-west-2"}`. 이미 고른 파이프라인도 새 리전을 따라감 |
| `hiddenProfiles` | `[]` | 뺄 프로필. 그 파이프라인은 패널에서 빠지고 다시 보이게 할 때까지 조회하지 않음 |
| `awsCLIPath` | — | `aws` 실행 파일 경로. 비우면 `/opt/homebrew/bin` · `/usr/local/bin` · `/usr/bin` 에서 찾음 |
| `pollIntervalSeconds` | `30` | 쉴 때 갱신 주기(초) |
| `activePollIntervalSeconds` | `10` | 배포 중일 때 갱신 주기(초) |
| `slowDownInLowPowerMode` | `true` | 저전력 모드면 두 주기를 두 배로 |
| `notificationsEnabled` | `true` | 알림 전체 켜기 · 끄기 |
| `notifyOnSuccess` · `notifyOnFailure` · `notifyOnApprovalRequest` · `notifyOnRejection` | `true` | 종류별 알림 |
| `notificationSound` | `true` | 알림 소리 |
| `language` | `"system"` | `"system"` · `"en"` · `"ko"` |

모든 파이프라인 조회가 실패하면(오프라인 · 세션 만료) 새로고침을 누르기 전까지 5분마다만 다시 시도함

## 문제 해결

**"인증 만료 · 터미널에서 aws sso login --profile …"**
안내대로 `aws sso login` 을 실행하고 패널의 새로고침(↻)을 누르면 바로 다시 조회함. 안 누르면 5분 안에 다시 시도

**"aws CLI 를 못 찾음"**
`brew install awscli` 로 설치하거나 `which aws` 결과를 **설정 → AWS** 에서 지정

**프로필은 보이는데 파이프라인이 없음**
대부분 리전 문제. `aws configure get region --profile <프로필>` 을 확인하고 필요하면 **설정 → AWS** 에서 그 프로필의 리전을 지정

**메뉴바에 아이콘이 안 보임**
노치가 있는 맥은 메뉴바에 자리가 모자라면 넘치는 아이템이 숨겨짐. 다른 아이템을 줄이거나 ⌘ 를 누른 채 아이콘을 끌어서 순서를 바꾸기

**알림이 안 옴**
시스템 설정 → 알림 → Crowsnest 에서 허용했는지 확인. 처음 실행할 때 권한을 물어봄

**로그 보기**

```bash
log stream --info --predicate 'subsystem == "com.ldhbenecia.crowsnest"'
```

## 개발

```bash
swift build                    # 빌드
./script/test.sh               # 테스트 (Command Line Tools 만 있어도 swift-testing 이 돌게 경로를 넘김)
./script/build_and_run.sh      # .app 으로 조립해서 실행 (--logs · --verify · --install)
./script/make_icon.sh          # 앱 아이콘과 dmg 창 배경 다시 그리기
./script/screenshots.sh        # docs/images 의 스크린샷을 예시 데이터로 다시 그리기
```

### 릴리스

버전은 `VERSION` 파일 하나로 관리함. 빌드할 때 커밋 해시 · 빌드 날짜와 함께 `Info.plist` 에 들어가고 정보 창에 보임

```bash
echo 0.2.0 > VERSION && git commit -am "chore: 0.2.0"
git tag v0.2.0 && git push origin main v0.2.0
```

`v*` 태그를 push 하면 [Release 워크플로](.github/workflows/release.yml)가 태그와 `VERSION` 이 같은지 확인하고, 테스트를 돌리고, `Crowsnest-0.2.0.dmg` 를 만들어 GitHub Release 에 dmg 와 `Crowsnest-0.2.0.dmg.sha256` 을 올림

릴리스 노트는 직전 태그부터의 커밋 메시지로 만들어짐(`feat` → Features, `fix` → Fixes, `perf` → Performance, `refactor` → Changes. `chore` · `ci` · `docs` · `test` · `build` 는 뺌). 태그를 달기 전에 `./script/release_notes.sh HEAD` 로 미리 볼 수 있음. push · PR 마다 [CI](.github/workflows/ci.yml)(빌드 · 테스트)도 돎

로컬에서 dmg 를 만들려면 `./script/package.sh`. ad-hoc 서명만 하고 공증은 하지 않음

## 라이선스

[MIT](LICENSE)
