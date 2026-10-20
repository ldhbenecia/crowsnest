# dmgbuild 설정 — package.sh 가 -D app=... -D background=... 로 경로를 넘김
# Finder 를 AppleScript 로 움직이지 않고 창 배치(.DS_Store)를 직접 써서 CI 에서도 똑같이 나옴
# 아이콘 위치는 Sources/IconRenderer 의 dmg 배경 화살표와 맞춰야 함

application = defines["app"]  # noqa: F821 — dmgbuild 가 넣어주는 값
background = defines["background"]  # noqa: F821

files = [application]
symlinks = {"Applications": "/Applications"}
hide_extensions = ["Crowsnest.app"]

format = "UDZO"
filesystem = "HFS+"

# 창 660 x 400, 툴바 · 경로 막대 · 상태 막대 없이 아이콘만
window_rect = ((200, 160), (660, 400))
default_view = "icon-view"
show_toolbar = False
show_pathbar = False
show_status_bar = False
show_sidebar = False
show_tab_view = False

icon_size = 128
text_size = 13
icon_locations = {
    "Crowsnest.app": (170, 186),
    "Applications": (490, 186),
}
