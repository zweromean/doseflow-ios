# Windows에서 IPA 만들기

현재 ZIP에는 소스와 빌드 자동화가 있습니다. 미리 생성된 IPA는 없습니다.

1. GitHub에서 저장소를 만들고 이 프로젝트 파일을 업로드합니다. `project.yml`, `DoseFlow`, `Shared`, `DoseFlowWidgets`, `scripts`, `.github`를 모두 포함하세요. `.github/workflows/build-ipa.yml`이 없으면 Actions 메뉴에 작업이 나타나지 않습니다.
2. 저장소의 Actions → Build iPhone IPA → Run workflow를 누릅니다.
3. 빌드가 성공하면 실행 페이지 하단 Artifacts에서 DoseFlow-unsigned-IPA를 다운로드합니다.
4. 다운로드한 artifact ZIP을 풀면 `DoseFlow-unsigned.ipa`가 나옵니다.
5. Windows에서 사용하는 사이드로드 도구로 이 IPA를 서명한 뒤 설치합니다. IPA는 서명 전 상태입니다. 도구의 iOS 버전 및 확장 앱 지원 여부를 확인하세요.

이 빌드에는 Apple 계정이나 서명 인증서를 GitHub에 입력할 필요가 없습니다. GitHub의 macOS 실행 시간은 계정/저장소 정책에 따라 요금 또는 사용 한도가 적용될 수 있습니다.

설치 도구 및 서명 방식에 따라 HealthKit, App Groups, 위젯, Live Activity 권한 유지 여부가 달라질 수 있습니다. IPA 생성 성공과 모든 확장 기능의 실기기 동작은 별개입니다.

실행 환경에서 Xcode 빌드는 아직 수행하지 않았습니다. 빌드가 실패하면 Actions의 실패 단계 로그로 컴파일 오류를 확인해야 합니다.
