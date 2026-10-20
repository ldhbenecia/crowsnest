# Crowsnest

AWS CodePipeline 배포 상태를 보여주는 macOS 메뉴바 앱. Swift 6 · SwiftUI `MenuBarExtra(.window)` · macOS 14+ · SwiftPM (Xcode 프로젝트 없음)

## 명령

```bash
swift build                          # 빌드
./script/test.sh                     # 테스트 — Command Line Tools 만 있으면 swift test 대신 이걸 씀
./script/build_and_run.sh            # .app 조립 후 실행 (--logs: 로그 스트림, --verify: 실행 확인, --install: /Applications)
./script/make_icon.sh                # Resources/AppIcon.icns · docs/images/icon.png 다시 그림
./script/screenshots.sh              # README 스크린샷(docs/images)을 예시 데이터로 다시 그림 — UI 를 바꾸면 같이 돌림
./script/package.sh                  # release dmg · .sha256 (VERSION 파일 기준) — 실제 릴리스는 v* 태그 push 로 .github/workflows/release.yml 이 만듦
./script/release_notes.sh HEAD       # 직전 태그부터의 커밋으로 만든 릴리스 노트 미리보기 — 커밋 제목이 곧 변경 내역이라 사용자 입장에서 씀
log stream --info --predicate 'subsystem == "com.ldhbenecia.crowsnest"'
```

## 구조

- `Sources/CrowsnestKit/AWS` — aws CLI 는 프로필 · 리전 · `export-credentials` 에만 씀. 파이프라인 조회는 SigV4 서명한 API 직접 호출 (`CodePipelineClient`)
- `Sources/CrowsnestKit/Models` — `PipelineSnapshot` · `PipelineCondition` (승인 대기 · 반려 구분)
- `Sources/CrowsnestKit/Store` — 갱신은 `PipelineStore` 의 폴링 루프 한 곳에서만, 나머지는 `requestRefresh` 로 대기만 깨움
- `Sources/CrowsnestKit/Views` — 패널 · 메뉴바 이미지 · 정보 창
- `Sources/CrowsnestApp` — `@main` 만
- `Sources/IconRenderer` — 앱 아이콘을 그리는 개발용 도구

## 규칙

- 공개 레포라 코드 · 테스트 · 커밋에 회사 정보(회사명, AWS 계정 ID, ARN, 실제 파이프라인 · 프로필 이름)를 넣지 않음. 커밋 전에 `git grep` 으로 확인
- 커밋은 conventional commit (`feat:`, `fix:` …), 논리 단위로 쪼갬, 음슴체 · 문장 끝 마침표 없음, Co-Authored-By 트레일러 없음
- 커밋 전에 `/simplify` · `/code-review` · `/security-review` 를 돌리고 반영
- push 는 요청이 있을 때만
- 주석은 코드로 알 수 없는 이유만 한두 줄, 음슴체
- 변수 · 필드 이름은 축약하지 않음
- 화면 · 알림 · 에러 문구는 `L("한국어", "English")` 로 둘 다 씀. 영어는 macOS 관례대로 버튼 · 메뉴는 Title Case. 로그는 한국어 그대로
- 배터리: 폴링마다 프로세스를 띄우지 않음, 패널이 닫혀 있으면 애니메이션을 멈춤
