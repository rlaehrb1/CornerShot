build:
    swift build
    mkdir -p CornerShot.app/Contents/MacOS CornerShot.app/Contents/Resources
    cp Resources/Info.plist CornerShot.app/Contents/Info.plist
    cp Resources/AppIcon.icns CornerShot.app/Contents/Resources/AppIcon.icns
    cp Resources/MenuBarIconTemplate.png CornerShot.app/Contents/Resources/MenuBarIconTemplate.png
    cp .build/debug/CornerShot CornerShot.app/Contents/MacOS/CornerShot
    codesign --force --deep --sign "CornerShot Local Development" CornerShot.app

run: build
    open CornerShot.app
