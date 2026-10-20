# 보안 정책

## 취약점 신고

공개 이슈에 올리지 말고 GitHub 의 [비공개 취약점 신고](https://github.com/ldhbenecia/crowsnest/security/advisories/new)로 알려주세요. 재현 방법과 영향 범위를 적어주면 확인 후 답장합니다.

최신 릴리스만 보안 수정을 받습니다.

## Crowsnest 가 다루는 정보

- **AWS 자격 증명**: `aws configure export-credentials --profile <프로필>` 로 받은 키를 메모리에만 들고 있다가 만료되면 다시 받습니다. 디스크 · 로그 · 설정 파일에 쓰지 않습니다.
- **네트워크**: `https://codepipeline.<리전>.amazonaws.com/` 에만 서명된 요청을 보냅니다. 리전 이름은 형식을 확인한 뒤에만 주소에 넣습니다.
- **열리는 링크**: 알림 · 콘솔 링크는 앱이 직접 만든 `console.aws.amazon.com` 주소이고, 빌드 로그 링크는 `http` · `https` 만 엽니다.
- **로컬 파일**: `~/.config/crowsnest/config.json` (리전 · 숨길 프로필 등, 비밀 값 없음) 과 선택한 파이프라인 목록(UserDefaults)만 씁니다.

읽기 권한(`codepipeline:ListPipelines`, `GetPipelineState`, `ListPipelineExecutions`)만 있으면 되고, 승인 · 재시도 같은 쓰기 동작은 하지 않습니다.
