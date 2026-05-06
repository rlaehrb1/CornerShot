# CornerShot

Hot corners for screenshots and clipboard history on macOS.

CornerShot is a small macOS menu bar app that lets each screen corner run a useful action, such as capturing a selected area or opening clipboard history.

## Download

Download the latest `CornerShot.zip` from the [Releases](https://github.com/rlaehrb1/CornerShot/releases) page.

After unzipping, move `CornerShot.app` to your Applications folder and open it.

CornerShot is currently signed for local development and is not notarized yet. If macOS blocks the first launch, right-click `CornerShot.app`, choose `Open`, then confirm once.

## Features

- Assign a separate action to each screen corner.
- Capture the full screen, a selected window, or a selected area.
- Open a local clipboard history window from a corner.
- Search clipboard text, file names, unsupported clipboard type names, and optional local OCR text from copied images.
- See existing macOS Hot Corner assignments and avoid direct conflicts.
- Switch between Korean and English in the app.

## Requirements

- macOS 14 or later.
- Screen Recording permission is required for screenshot features.

## Build From Source

```bash
swift build
```

If you have `just` installed, you can build the app bundle with:

```bash
just build
```

## Korean

CornerShot은 macOS용 작은 메뉴바 앱입니다. 화면의 네 모서리마다 원하는 동작을 지정하고, 마우스를 그 모서리로 가져가면 해당 동작을 실행합니다.

macOS 기본 핫코너와 비슷한 방식으로 쓰되, CornerShot만의 동작을 추가하는 것이 목표입니다.

### 어디에 보이나요?

앱을 실행하면 화면 맨 위 메뉴바 오른쪽에 CornerShot 아이콘이 생깁니다.

그 아이콘을 클릭하면 CornerShot 메뉴가 열립니다.

### 설정 창 열기

메뉴바 아이콘을 클릭한 뒤 `Hot Corner Settings...`를 누르면 설정 창이 열립니다.

설정 창에는 네 모서리가 모두 보입니다.

- `Top Left`: 왼쪽 위
- `Top Right`: 오른쪽 위
- `Bottom Left`: 왼쪽 아래
- `Bottom Right`: 오른쪽 아래

각 모서리마다 CornerShot에서 실행할 동작을 따로 고를 수 있습니다.

설정창 구상 이미지는 `docs/settings-window-mockup.svg`에 들어 있습니다.

### 언어 설정

CornerShot은 앱 안에서 한국어와 영어를 바꿀 수 있습니다.

- 메뉴바 아이콘을 클릭한 뒤 `언어` 또는 `Language` 메뉴에서 바꿀 수 있습니다.
- 설정 창 오른쪽 위의 언어 선택 메뉴에서도 바꿀 수 있습니다.
- 메뉴, 설정 창, 클립보드 창의 주요 문구가 선택한 언어로 바뀝니다.

### 메뉴바 메뉴

메뉴바의 CornerShot 아이콘을 클릭하면 자주 쓰는 관리 기능을 바로 실행할 수 있습니다.

- `스크린샷 폴더 열기`: 현재 CornerShot이 사용하는 스크린샷 저장 폴더를 Finder에서 엽니다.
- `클립보드 모두삭제`: 핀으로 고정하지 않은 클립보드 항목과 해당 OCR 데이터를 삭제합니다. 실행 전 경고창으로 한 번 더 확인합니다.

### 실행할 수 있는 동작

각 모서리의 팝업 메뉴에서 아래 동작을 선택할 수 있습니다.

- `None`: 이 모서리에서는 아무것도 실행하지 않습니다.
- `Screenshot: Full Screen`: 전체 화면을 바로 캡처합니다.
- `Screenshot: Selected Window`: 원하는 창을 클릭해서 그 창만 캡처합니다.
- `Screenshot: Selected Area`: 마우스로 원하는 영역을 드래그해서 캡처합니다.
- `Show Clipboard Window`: 클립보드 히스토리 창을 엽니다.

맥 초보자라면 스크린샷은 `Screenshot: Selected Area`가 가장 익숙합니다. 키보드 단축키 `Command + Shift + 4`와 비슷한 방식입니다.

### macOS 기본 핫코너 표시

CornerShot 설정 창은 각 모서리에 이미 설정된 macOS 기본 핫코너도 함께 보여줍니다.

예를 들면 이렇게 표시됩니다.

```text
macOS: Desktop
macOS: Command Lock Screen
macOS: None
```

`macOS: None`이면 macOS 기본 핫코너가 없는 상태라 CornerShot이 바로 사용할 수 있습니다.

### 충돌 방지

macOS 기본 핫코너가 수정키 없이 이미 설정된 모서리에서는 CornerShot이 일부러 실행되지 않습니다.

예를 들어 오른쪽 아래가 macOS에서 `Desktop`으로 설정되어 있다면, CornerShot에서 오른쪽 아래에 클립보드 창을 지정해도 실제로는 실행하지 않습니다. 이렇게 해야 macOS 동작과 CornerShot 동작이 동시에 튀어나오는 일을 피할 수 있습니다.

그 모서리를 CornerShot에서 쓰고 싶다면 macOS 설정에서 해당 핫코너를 `-` 또는 `None`으로 바꾼 뒤, CornerShot 설정 창에서 `Refresh macOS`를 누르면 됩니다.

CornerShot의 선택 메뉴는 충돌 중인 모서리에서도 계속 수정할 수 있습니다. 다만 빨간색으로 표시된 모서리는 macOS 설정이 우선이라 실제 동작은 잠시 막힙니다.

수정키가 붙은 macOS 핫코너는 일반 마우스 이동과는 직접 충돌하지 않습니다. 예를 들어 `Command Lock Screen`처럼 표시되면 Command 키를 누른 상태에서만 macOS 핫코너가 동작합니다.

### 클립보드 히스토리 창

`Show Clipboard Window`를 선택하면 해당 모서리로 마우스를 가져갔을 때 클립보드 히스토리 창이 열립니다.

- CornerShot이 실행된 뒤 복사한 항목들이 최신순으로 쌓입니다.
- 창은 현재 마우스가 있는 화면의 왼쪽 위에 열리고, 항목 수에 맞춰 자동으로 작아지거나 커집니다.
- 텍스트, 이미지, Finder 파일을 우선 지원합니다.
- 긴 텍스트는 15글자 뒤에 `...` 말줄임표로 줄이고, 항목 위에 마우스를 올리면 전체 텍스트를 볼 수 있습니다.
- 같은 항목을 다시 복사하면 중복으로 추가하지 않고 맨 위로 올립니다.
- 검색창에 키워드를 입력하면 텍스트, 파일명, 지원하지 않는 타입 이름, OCR 텍스트가 포함된 항목만 최신순으로 표시합니다.
- 최대 50개까지 보관하고, 오래된 항목부터 자동으로 지웁니다.
- 각 항목의 `핀` 버튼을 누르면 고정됩니다. 고정된 항목은 오래되어도 자동 삭제되지 않고, `Clear History`를 눌러도 남습니다.
- 각 항목의 `X` 버튼을 누르면 그 항목만 삭제합니다. 이 명시적 삭제는 고정 항목에도 적용됩니다.
- 아직 미리보기를 지원하지 않는 클립보드 형식도 빈 화면으로 처리하지 않고, 들어있는 클립보드 타입 목록을 보여줍니다.
- 설정 창에서 `이미지 OCR 검색 사용`을 켜면 새 이미지 항목의 텍스트를 로컬에서 인식해 검색에 포함합니다. OCR이 끝난 이미지에는 작은 파란 점이 표시됩니다.

창 안의 `Refresh` 버튼을 누르면 현재 클립보드를 다시 읽고, `Clear History`를 누르면 히스토리를 비웁니다.

각 항목은 다른 앱이나 Finder 창으로 드래그할 수 있습니다.

- 텍스트 항목은 텍스트로 드래그됩니다.
- 이미지 항목은 Finder와 다른 앱이 받을 수 있는 TIFF 파일로 드래그됩니다.
- 파일 항목은 파일 URL로 드래그됩니다.

기본값으로 히스토리는 `Application Support/CornerShot/clipboard-history`에 로컬로 저장되어 앱 재시작 후에도 복원됩니다. 설정 창의 `앱 종료 후에도 클립보드 히스토리 저장`을 끄면 앱 실행 중에만 유지됩니다.

OCR을 켜면 이미지 안에서 인식된 텍스트도 로컬 히스토리에 함께 저장됩니다. 기존 이미지 히스토리는 자동으로 다시 처리하지 않고, OCR을 켠 뒤 새로 들어온 이미지부터 처리합니다.

핫코너 감지는 마우스 이동 이벤트와 짧은 백업 타이머를 함께 사용합니다. 화면의 아주 끝 경계에 포인터가 닿아도 감지되도록 모서리 판정 범위를 넓혀두었습니다.

### 스크린샷 파일은 어디에 저장되나요?

스크린샷 동작을 사용할 때 CornerShot은 설정 창의 `스크린샷 저장 위치`를 따릅니다.

저장 위치를 따로 고르지 않으면 macOS의 현재 스크린샷 저장 위치를 사용합니다.

따로 바꾼 적이 없다면 보통 데스크탑에 저장됩니다.

파일 이름은 이런 형태입니다.

```text
CornerShot 2026-04-28 14.30.10.png
```

스크린샷이 저장되면 `Command + Shift + 4`처럼 화면 오른쪽 아래에 작은 미리보기가 잠시 나타납니다. 미리보기를 드래그하면 저장된 PNG 파일을 다른 앱이나 Finder로 끌어놓을 수 있고, 클릭하면 Finder에서 저장된 파일 위치를 보여줍니다.

### 화면 기록 권한 안내가 반복될 때

macOS가 `화면 및 시스템 오디오 기록` 권한을 요청하면 CornerShot을 허용한 뒤 앱을 완전히 종료하고 다시 열어야 합니다.

개발 중 새로 빌드한 앱은 macOS가 다른 앱처럼 볼 수 있으므로, 권한 안내가 꼬이면 `local.mackim.CornerShot`의 화면 기록 권한을 초기화한 뒤 새 버전을 다시 허용하면 됩니다.

### 켜기 / 끄기

메뉴의 `Enabled` 항목으로 CornerShot을 켜거나 끌 수 있습니다.

- 체크되어 있으면 켜진 상태입니다.
- 체크가 없으면 모든 CornerShot 핫코너 동작이 멈춥니다.

### 종료하기

메뉴에서 `Quit CornerShot`을 누르면 앱이 종료됩니다.

### 실행 방법

앱 번들을 열려면:

```bash
open CornerShot.app
```

개발 중에 바로 실행하려면:

```bash
swift run
```

`just`가 설치되어 있다면 빌드 후 실행할 수 있습니다.

```bash
just run
```

## English

CornerShot is a small macOS menu bar app. It lets you assign a custom action to each of the four screen corners, then run that action by moving your mouse into the corner.

The goal is to feel similar to macOS Hot Corners while adding CornerShot-specific actions.

### Where does it appear?

After launching the app, a lightning icon appears on the right side of the macOS menu bar at the top of the screen.

Click that icon to open the CornerShot menu.

### Open Settings

Click the menu bar icon, then choose `Hot Corner Settings...`.

The settings window shows all four corners.

- `Top Left`
- `Top Right`
- `Bottom Left`
- `Bottom Right`

Each corner can have its own CornerShot action.

The settings-window mockup lives at `docs/settings-window-mockup.svg`.

### Language

CornerShot can switch between Korean and English inside the app.

- Use the `언어` or `Language` menu from the menu bar icon.
- You can also change it from the language picker in the top-right of the settings window.
- Main menu, settings window, and clipboard window labels follow the selected language.

### Menu Bar Menu

Click the CornerShot menu bar icon to run common management actions quickly.

- `Open Screenshot Folder`: Opens the screenshot save folder currently used by CornerShot.
- `Clear Clipboard`: Deletes unpinned clipboard items and their OCR data after a warning confirmation. Pinned items are kept.

### Available Actions

Use the pop-up menu for each corner to choose an action.

- `None`: Do nothing for this corner.
- `Screenshot: Full Screen`: Capture the whole screen immediately.
- `Screenshot: Selected Window`: Click a window and capture only that window.
- `Screenshot: Selected Area`: Drag over the area you want to capture.
- `Show Clipboard Window`: Open the clipboard history window.

If you are new to macOS, `Screenshot: Selected Area` is probably the most familiar screenshot option. It works similarly to the `Command + Shift + 4` shortcut.

### macOS Hot Corner Display

The CornerShot settings window also shows the macOS Hot Corner already assigned to each corner.

For example:

```text
macOS: Desktop
macOS: Command Lock Screen
macOS: None
```

`macOS: None` means macOS is not using that corner, so CornerShot can use it directly.

### Conflict Avoidance

If macOS already uses a corner without a modifier key, CornerShot intentionally does not run on that corner.

For example, if the bottom-right corner is set to `Desktop` in macOS, assigning `Show Clipboard Window` to bottom-right in CornerShot will not run there. This prevents the macOS action and the CornerShot action from firing at the same time.

To use that corner in CornerShot, change the macOS Hot Corner to `-` or `None`, then click `Refresh macOS` in the CornerShot settings window.

CornerShot choices remain editable even on conflicting corners. A red corner is saved, but it will not run until the macOS setting is cleared or changed.

macOS Hot Corners with modifier keys do not directly conflict with plain mouse movement. For example, `Command Lock Screen` only runs when the Command key is held.

### Clipboard History Window

Choose `Show Clipboard Window` to open a clipboard history window when your mouse touches that corner.

- Items copied while CornerShot is running are collected with the newest item at the top.
- The window opens at the top-left of the screen your pointer is on, then automatically grows or shrinks based on the number of history items.
- Text, images, and Finder files are supported first.
- Long text is shortened after 15 characters with `...`; hover the row to see the full text.
- Copying the same item again moves the existing row to the top instead of creating a duplicate.
- Type in the search field to show only items whose text, file name, unsupported type name, or OCR text contains the keyword. Results keep newest-first order.
- CornerShot keeps up to 50 items and removes the oldest items automatically.
- Click the `Pin` button on a row to keep it. Pinned items are not removed by age or by `Clear History`.
- Click the `X` button on a row to delete only that item. This explicit delete also works on pinned items.
- Unsupported clipboard formats are no longer shown as empty; CornerShot lists the clipboard types it found.
- Turn on `Use image OCR search` in settings to recognize text from new image items locally. Images show a small blue dot after OCR finishes.

Click `Refresh` inside the window to read the current clipboard again. Click `Clear History` to remove all history rows.

Each row can be dragged into another app or Finder window.

- Text rows drag as text.
- Image rows drag as TIFF files that Finder and other apps can receive.
- File rows drag as file URLs.

By default, history is saved locally under `Application Support/CornerShot/clipboard-history` and restored after restarting the app. Turn off `Keep clipboard history after quit` in the settings window to keep history only while the app is running.

When OCR is enabled, recognized image text is also stored in the local history. Existing image history is not processed retroactively; OCR starts with new images copied after the setting is enabled.

Hot-corner detection now uses mouse movement events plus a short backup timer. The corner hit area is also wider so the pointer is still detected when it lands exactly on the screen edge.

### Where are screenshots saved?

When using a screenshot action, CornerShot follows the `Screenshot Save Location` in the settings window.

If you do not choose a custom folder, CornerShot uses the current macOS screenshot save location.

If you have not changed that setting, screenshots are usually saved to the Desktop.

File names look like this:

```text
CornerShot 2026-04-28 14.30.10.png
```

After a screenshot is saved, a small preview appears briefly in the bottom-right corner, similar to `Command + Shift + 4`. Drag the preview to drop the saved PNG file into Finder or another app, or click it to reveal the saved file in Finder.

### If Screen Recording Keeps Asking

When macOS asks for `Screen & System Audio Recording`, allow CornerShot, then fully quit and reopen the app.

During development, a newly built app can look like a different app to macOS. If the permission entry gets stuck, reset ScreenCapture permission for `local.mackim.CornerShot`, then allow the newly built app again.

### Enable / Disable

Use the `Enabled` menu item to turn CornerShot on or off.

- If it is checked, CornerShot is active.
- If it is unchecked, all CornerShot hot-corner actions are paused.

### Quit

Click `Quit CornerShot` in the menu to close the app.

### Run

Open the app bundle:

```bash
open CornerShot.app
```

Run directly while developing:

```bash
swift run
```

If `just` is installed, build and run with:

```bash
just run
```
