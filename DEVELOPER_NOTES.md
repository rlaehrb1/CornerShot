# CornerShot Developer Notes

Last updated: 2026-04-29

이 문서는 현재까지 CornerShot에 구현한 기능, 구조, 보안/권한 결정, 남겨둔 기술 부채를 이어서 개발하기 쉽게 정리한 개발자 노트다. 사용자용 설명은 `README.md`, UI 원칙은 `DESIGN.md`를 우선 참고한다.

## Project Snapshot

CornerShot은 macOS 메뉴바 유틸리티 앱이다. 사용자가 네 모서리 핫코너에 스크린샷 또는 클립보드 히스토리 동작을 지정하고, 마우스를 해당 모서리로 가져가면 지정된 동작을 실행한다.

- SwiftPM executable target: `CornerShot`
- Minimum macOS: 14.0
- Bundle identifier: `local.mackim.CornerShot`
- App mode: `LSUIElement` menu bar app
- Main build command: `swift build`
- App bundle build/sign command: `just build`
- Local signing identity: `CornerShot Local Development`

## Source Layout

`main.swift`는 앱 시작만 담당하고, 기능은 아래 파일로 나뉘어 있다.

- `AppDelegate.swift`: 앱 수명주기, 메뉴바 아이콘/메뉴, 컨트롤러 연결.
- `AppLanguage.swift`: 한국어/영어 언어 모델과 `text(...)` helper.
- `CornerModels.swift`: `CaptureMode`, `CornerAction`, `HotCorner`.
- `Settings.swift`: `UserDefaults` 기반 설정, legacy 설정 마이그레이션, 스크린샷 저장 위치 해석.
- `SystemHotCorner.swift`: macOS Dock 핫코너 설정 읽기, modifier 값 해석, 충돌 판단.
- `CornerMonitor.swift`: 마우스 위치 감시, 코너 arm/disarm, 액션 실행.
- `ScreenshotRunner.swift`: 화면 기록 권한 확인, `screencapture` 실행, 저장 실패 알림, 미리보기 패널.
- `ClipboardHistory.swift`: 클립보드 수집/저장/OCR/검색/창 UI/드래그 지원.
- `OCRReader.swift`: Vision 기반 로컬 OCR.
- `SettingsWindowController.swift`: 설정창 UI.
- `CornerShotDesign.swift`: AppKit UI에서 쓰는 디자인 토큰/helper.

## Implemented Features

### Hot Corners

- 네 모서리 각각에 동작을 지정할 수 있다.
- 가능한 동작:
  - 없음
  - 스크린샷: 전체 화면
  - 스크린샷: 선택한 윈도우
  - 스크린샷: 선택 영역
  - 클립보드 창 보기
- 마우스가 모서리에 들어오면 한 번만 실행되도록 `armedCorners`로 재진입을 막는다.
- 포인터가 모서리를 벗어나면 다시 arm된다.
- macOS 자체 핫코너와 충돌하면 CornerShot 동작을 억제한다.
- macOS 핫코너에 Command/Option/Control/Shift modifier가 설정된 경우, 현재 modifier 조합이 macOS 설정을 만족할 때만 CornerShot을 막는다.
- modifier macOS 핫코너가 CornerShot을 막은 경우에도 해당 코너를 disarm해서, 키를 뗀 뒤 같은 코너 안에서 CornerShot이 뒤따라 실행되지 않게 했다.

### Menu Bar Actions

- 메뉴바 아이콘에서 CornerShot 활성화/비활성화, 설정창 열기, 언어 변경, 현재 코너 설정 요약, 종료를 제공한다.
- `스크린샷 폴더 열기`는 현재 `Settings.screenshotDirectoryURL`을 Finder에서 연다.
- `클립보드 모두삭제`는 경고창으로 확인한 뒤 unpinned 클립보드 항목과 해당 OCR 데이터를 삭제한다.
- pinned 항목은 메뉴 삭제에서도 유지된다.

### Screenshots

- 실제 캡처는 `/usr/sbin/screencapture`를 사용한다.
- 선택 영역은 `screencapture -i -s`, 선택 윈도우는 `screencapture -i -w`로 실행한다.
- 실행 전 `CGPreflightScreenCaptureAccess()`로 화면 기록 권한을 먼저 확인한다.
- 권한이 없으면 `CGRequestScreenCaptureAccess()`를 호출하고 캡처는 중단한다.
- 저장 위치는 설정에서 지정 가능하다.
- 저장 위치 우선순위:
  1. 사용자가 CornerShot 설정에서 지정한 유효한 폴더
  2. macOS `com.apple.screencapture`의 `location`
  3. Desktop
- 파일명은 `CornerShot yyyy-MM-dd HH.mm.ss.SSS <short-uuid>.png` 형식이다.
- 같은 초 안에 여러 장을 찍어도 덮어쓰지 않도록 밀리초와 UUID suffix를 붙인다.
- 저장 폴더 생성 또는 `screencapture` 실행/완료 실패 시 사용자에게 경고 알림을 띄운다.
- 캡처 후 macOS 기본 스크린샷과 비슷한 작은 미리보기 패널을 5초 동안 띄운다.
- 미리보기 패널은 스크린샷 크기와 무관하게 고정 크기다.
- 미리보기는 드래그 앤 드롭 가능하며, 이미 저장된 PNG 파일 URL을 그대로 사용한다.
- 미리보기 드래그가 완료되면 패널을 즉시 닫는다.
- 미리보기를 클릭하면 Finder에서 저장 파일을 선택한다.

### Clipboard History

- 앱 시작 시 현재 클립보드를 즉시 저장하지 않는다.
- `ClipboardHistoryStore.start()`는 현재 `changeCount`만 기록하고, 앱 실행 후 클립보드가 바뀐 경우에만 수집한다.
- `Refresh` 버튼은 사용자 명시 동작이므로 현재 클립보드를 수동으로 ingest한다.
- 최대 기본 히스토리는 unpinned 기준 50개다.
- pinned 항목은 trim 대상에서 제외된다.
- 저장 유지 옵션은 기본 ON이다.
- 저장 유지가 켜져 있으면 `Application Support/CornerShot/clipboard-history/history.json`에 저장된다.
- 저장 유지가 꺼지면 저장 파일을 삭제한다.
- 지원하는 항목:
  - 텍스트
  - 이미지
  - 파일 URL
  - 지원하지 않는 pasteboard 타입 목록
- 중복 항목은 새 항목으로 추가하지 않고 기존 항목을 최신 위치로 올린다.
- 텍스트/파일명/지원하지 않는 타입/OCR 텍스트를 `searchText` 캐시로 합쳐 빠르게 검색한다.
- 검색 결과 정렬은 관련도순이 아니라 기존 최신순을 유지한다.

### Clipboard Window UI

- 클립보드 창은 열 때 현재 마우스가 있는 화면의 왼쪽 위에 배치한다.
- 이미 열려 있는 상태에서 항목 추가/삭제/고정/OCR 완료/언어 변경이 발생해도 창 위치를 강제로 왼쪽 위로 되돌리지 않는다.
- 창을 닫았다 다시 열면 최신 항목이 보이도록 스크롤을 맨 위로 맞춘다.
- 항목 row 높이는 64pt로 통일했다.
- row 가로폭은 list 폭에 맞게 통일해서 항목별로 들쭉날쭉하지 않게 했다.
- 창은 기본적으로 compact하게 열리며, 보이는 row 수는 최대 4개 기준이다.
- 항목별 액션:
  - pin/unpin
  - delete
  - drag handle
- OCR 처리 완료 이미지에는 우측 상단에 작은 파란 점을 표시한다.

### Clipboard Drag And Drop

- 텍스트 항목은 `NSString` pasteboard writer로 드래그한다.
- 파일 항목은 기존 file URL을 드래그한다.
- 이미지 항목은 대상 앱 호환성을 위해 임시 PNG 파일 URL과 이미지 데이터를 같이 제공한다.
- 이미지 drag writer가 제공하는 타입:
  - `public.file-url`
  - `NSFilenamesPboardType`
  - `public.url`
  - `public.url-name`
  - PNG data
  - TIFF data
- Codex 앱은 Finder식 file promise만으로는 드롭을 받지 못해서, 실제 임시 파일 URL을 같이 주도록 바꿨다.
- 임시 파일은 system temporary directory 아래 `CornerShot/DragItems`에 만들고, 드롭 완료 후 약 120초 뒤 삭제한다.
- 드래그가 취소되면 즉시 삭제한다.
- 오래 남은 임시 drag 파일은 다음 이미지 드래그 시 10분 기준으로 정리한다.
- 예전에 사용하던 `~/Library/Caches/CornerShot/DragItems` legacy 캐시는 앱 시작 시 삭제한다.

### OCR Search

- 설정창에 `이미지 OCR 검색 사용` 옵션을 추가했다.
- 기본값은 OFF다.
- OCR은 옵션을 켠 뒤 새로 들어오는 이미지 항목에만 자동 적용한다.
- 기존 저장 이미지 히스토리를 retroactive하게 OCR 처리하지 않는다.
- Apple Vision `VNRecognizeTextRequest`를 사용한다.
- 인식 언어는 `ko-KR`, `en-US`다.
- OCR queue는 serial utility queue라 한 번에 하나씩 처리한다.
- OCR 완료 시 `ocrText`, `isOCRProcessed`, `searchText`를 갱신하고 UI를 reload한다.
- 텍스트가 인식되지 않아도 OCR 처리 완료 상태이면 파란 배지를 표시한다.

### UI/Design

- `DESIGN.md`를 추가해 CornerShot UI 기준을 문서화했다.
- 목표 톤은 조용하고 읽기 쉬운 macOS utility다.
- `CornerShotDesign.swift`에 radius, spacing, font, surface, button helper를 모았다.
- `Resources/AppIcon.icns`를 추가해 macOS 기본 도면 아이콘 대신 CornerShot 앱 아이콘을 번들에 포함한다.
- 앱 아이콘은 생성 후보 이미지의 중앙 상단 후보를 `Resources/AppIconSource.png`로 잘라 만든다.
- 앱 아이콘 PNG/iconset/icns와 메뉴바 템플릿 아이콘은 `scripts/generate_app_icon.swift`로 재생성할 수 있다.
- 메뉴바 아이콘은 `Resources/MenuBarIconTemplate.png`를 template image로 사용하고, 실패 시 SF Symbol로 fallback한다.
- 설정창은 네 핫코너 패널과 화면 preview 중심으로 구성한다.
- macOS 핫코너 충돌은 빨간 상태, modifier 조건은 주의 상태로 표시한다.
- 클립보드 row는 primary line + muted metadata + 작은 icon controls 구조다.

## Permissions And Signing

macOS 화면 기록 권한은 앱 번들 식별자와 코드 서명 상태에 민감하다. 개발 중에는 같은 bundle identifier와 같은 로컬 개발 인증서를 유지해야 권한이 덜 꼬인다.

- Bundle ID: `local.mackim.CornerShot`
- Info.plist source: `Resources/Info.plist`
- Built app plist: `CornerShot.app/Contents/Info.plist`
- Signing command in `justfile`: `codesign --force --deep --sign "CornerShot Local Development" CornerShot.app`

권한이 꼬였을 때 임시 복구 절차:

1. 실행 중인 CornerShot을 완전히 종료한다.
2. 필요하면 ScreenCapture 권한을 reset한다.
3. `just build`로 새 앱 번들을 만든다.
4. `CornerShot.app`을 실행한다.
5. 스크린샷 기능을 실행해 macOS 권한 팝업에서 허용한다.
6. 허용 후 앱을 한 번 더 종료했다 다시 실행한다.

주의: 코드 변경 자체마다 항상 새 권한이 필요한 것은 아니다. 하지만 앱 번들을 새로 만들거나 서명/식별자가 바뀌면 macOS가 다른 앱처럼 볼 수 있다. 그래서 개발 중에는 `Resources/Info.plist`와 `CornerShot Local Development` 서명을 고정했다.

## Build And Run

기본 빌드:

```sh
swift build
```

앱 번들 생성 및 서명:

```sh
just build
```

빌드 후 실행:

```sh
just run
```

수동 검증에 자주 쓴 명령:

```sh
codesign --verify --deep --strict --verbose=2 CornerShot.app
plutil -lint Resources/Info.plist CornerShot.app/Contents/Info.plist
```

## Data Storage

- App settings: `UserDefaults.standard`
- Clipboard history: `~/Library/Application Support/CornerShot/clipboard-history/history.json`
- Legacy image drag cache cleanup target: `~/Library/Caches/CornerShot/DragItems`
- Current temporary image drag files: system temp directory under `CornerShot/DragItems`
- Screenshot files: user-selected folder, macOS screenshot folder, or Desktop

보안상 중요한 점:

- 클립보드 히스토리 저장 유지가 켜져 있으면 텍스트, 이미지 TIFF data, OCR text가 로컬 디스크에 저장된다.
- OCR은 네트워크를 쓰지 않고 로컬 Vision framework만 사용한다.
- 시작 전 클립보드는 자동 저장하지 않도록 수정했다.
- 이미지 드래그용 임시 파일은 짧게 유지하고 정리한다.

## Known Tradeoffs And Deferred Work

### Large Clipboard Images

현재 이미지 클립보드는 TIFF data를 `history.json` 안에 그대로 저장한다. JSON 안에서는 binary data가 Base64처럼 커져 저장되므로, 큰 스크린샷/사진 몇 장만으로도 history 파일이 커질 수 있다. 파일이 커지면 저장할 때 전체 배열을 다시 인코딩/쓰기 때문에 UI 반응성과 디스크 사용량에 영향을 줄 수 있다.

이번 단계에서는 이 부분을 그대로 두기로 했다. 나중에 개선한다면 아래 방향이 좋다.

- 원본 이미지 저장 크기 제한
- 썸네일과 원본 분리
- 이미지 data를 JSON 밖 별도 파일로 저장
- 비동기 저장
- 항목별 최대 용량 제한
- 민감 이미지 저장에 대한 명확한 옵션/경고

### Clipboard Persistence Security

기본값이 저장 유지 ON이라 편의성은 좋지만, 사용자가 복사한 민감한 텍스트/이미지/OCR 결과가 로컬 파일에 남을 수 있다. 배포용으로 다듬을 때는 onboarding에서 이 점을 명확히 안내하거나 기본값 OFF 전환을 검토할 수 있다.

### OCR Scope

OCR은 새 이미지부터 처리한다. 기존 히스토리에 대해 일괄 OCR을 돌리는 기능은 아직 없다. 추가한다면 진행 상태, 취소, 삭제된 항목 무시, 저장 부하를 같이 설계해야 한다.

### Notarization / Distribution

현재는 로컬 개발 인증서 기반이다. 다른 사람에게 배포하려면 Developer ID 서명, hardened runtime, notarization, 권한 안내 플로우를 별도로 정리해야 한다.

## Regression Checklist

핫코너:

- modifier 없는 macOS 핫코너가 있는 모서리에서는 CornerShot이 실행되지 않는다.
- Command/Option/Control/Shift macOS 핫코너는 해당 modifier를 누른 동안 CornerShot을 막는다.
- modifier를 뗀 뒤에도 포인터가 같은 모서리에 머물러 있으면 CornerShot이 뒤따라 실행되지 않는다.
- 포인터가 모서리를 벗어났다가 다시 들어가면 정상 실행된다.

스크린샷:

- 권한이 없을 때 `screencapture`를 반복 호출하지 않고 권한 요청만 한다.
- 선택 영역/선택 윈도우/전체 화면 캡처가 지정 폴더에 저장된다.
- 같은 초 안에 연속 캡처해도 파일이 덮어써지지 않는다.
- 저장 실패 시 사용자에게 알림이 뜬다.
- 미리보기는 항상 같은 크기로 뜨고, 5초 뒤 사라진다.
- 미리보기를 드래그해서 Codex/Finder 등에 놓을 수 있고, 드롭 완료 시 미리보기가 닫힌다.

클립보드:

- 앱 시작 전 클립보드는 자동으로 히스토리에 들어가지 않는다.
- 앱 시작 후 새로 복사한 텍스트/이미지/파일은 들어간다.
- `Refresh`는 현재 클립보드를 수동 추가한다.
- 메뉴바의 `클립보드 모두삭제`는 삭제 전 경고창을 띄운다.
- 메뉴바 삭제는 pinned 항목을 남기고 unpinned 항목과 해당 OCR 데이터만 삭제한다.
- 검색창 입력 즉시 결과가 최신순으로 필터링된다.
- 이미지 OCR 옵션 기본값은 OFF다.
- OCR ON 후 새 이미지가 들어오면 OCR 완료 뒤 파란 점이 표시된다.
- OCR 텍스트로 검색된다.
- 창을 옮긴 뒤 항목이 갱신되어도 창 위치가 튀지 않는다.
- 창을 닫았다 다시 열면 최신 항목이 보이는 위치로 스크롤된다.
- row 가로폭과 높이가 균일하다.
- 이미지 항목을 Codex 입력창에 드래그하면 붙는다.

빌드/서명:

- `swift build` 통과.
- `just build` 통과.
- `codesign --verify --deep --strict --verbose=2 CornerShot.app` 통과.
- `plutil -lint Resources/Info.plist CornerShot.app/Contents/Info.plist` 통과.
