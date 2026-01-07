#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"emoji,hint,-loader,-ver,-parser"} # enable emoji and hint loggers, disable internals

# shellcheck disable=SC2155 # evaluate E_BASH from project structure if it's not set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# shellcheck source=../.scripts/_colors.sh
source /dev/null # trick shellcheck

# include logger and colors support
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$E_BASH/_logger.sh"

# register loggers
logger emoji "$@" && logger:redirect emoji ">&1"
logger hint "$@" && logger:prefix hint "${cl_gray}" && logger:redirect hint ">&1"

function detect:terminal:capabilities() {
    local locale_utf8 term_type term_program has_color_emoji

    # Check locale for UTF-8 support
    locale_utf8=$(locale | grep -i "utf-8" | wc -l)

    # Get terminal type
    term_type="${TERM:-unknown}"
    term_program="${TERM_PROGRAM:-unknown}"

    # Check if terminal is known to support color emojis well
    has_color_emoji=0
    case "$term_program" in
        iTerm.app|WezTerm|Alacritty) has_color_emoji=1 ;;
    esac

    case "$term_type" in
        *256color*|*truecolor*|xterm-kitty) has_color_emoji=1 ;;
    esac

    # Report findings
    echo:Hint "${cl_cyan}Terminal Detection:${cl_reset}"
    echo:Hint "  TERM: ${cl_yellow}${term_type}${cl_reset}"
    [[ "$term_program" != "unknown" ]] && echo:Hint "  TERM_PROGRAM: ${cl_yellow}${term_program}${cl_reset}"
    echo:Hint "  UTF-8 Locale: ${cl_yellow}$([[ $locale_utf8 -gt 0 ]] && echo "Yes" || echo "No")${cl_reset}"
    echo:Hint "  Emoji Support: ${cl_yellow}$([[ $has_color_emoji -eq 1 ]] && echo "Good" || echo "Limited")${cl_reset}"
    echo:Hint ""

    return $has_color_emoji
}

function get:emoji:width() {
    local emoji="$1" width

    # Use printf with field width to estimate character width
    # Emojis that render properly typically take 2 columns
    width=$(printf "%s" "$emoji" | wc -m)
    echo "$width"
}

function print:category() {
    local category="$1"

    echo:Emoji ""
    printf:Emoji "%s%s%s%s\n" "${st_bold}" "${cl_cyan}" "$category" "${cl_reset}"
}

function print:emoji:line() {
    local emojis=("$@") emoji

    for emoji in "${emojis[@]}"; do
        printf:Emoji " [%s] " "$emoji"
    done
    echo:Emoji ""
}

function report:emojis() {
    # Smileys & Emotion
    print:category "😀 Smileys & Emotion"
    print:emoji:line 😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 😉 😊 😇
    echo:Hint "  ${cl_gray}# Newer emojis (Unicode 14+): 🫠 🫢 🫣 🫡 🫥 🫤 🥹 may not render on older terminals${cl_reset}"
    print:emoji:line 🥰 😍 🤩 😘 😗 😚 😙 🥲 😋 😛 😜 🤪 😝 🤑
    print:emoji:line 🤗 🤭 🤫 🤔 🤐 🤨 😐 😑 😶 😏
    print:emoji:line 😒 🙄 😬 🤥 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢
    print:emoji:line 🤮 🤧 🥵 🥶 😵 🤯 🤠 🥳 🥸 😎 🤓 🧐
    echo:Hint "  ${cl_gray}# Compound emojis with ZWJ sequences: 😮‍💨 😶‍🌫️ 😵‍💫 need advanced font support${cl_reset}"
    print:emoji:line 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰
    print:emoji:line 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠
    print:emoji:line 🤬 😈 👿 💀 💩 🤡 👹 👺 👻 👽 👾 🤖 💯

    # Hearts & Love
    print:category "❤️ Hearts & Love"
    print:emoji:line ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❤️‍🔥 ❤️‍🩹 💕
    print:emoji:line 💞 💓 💗 💖 💘 💝 💟 💌 💋 💏 💑

    # Hand Gestures
    print:category "👋 Hand Gestures"
    print:emoji:line 👋 🤚 🖐️ ✋ 🖖 🫱 🫲 🫳 🫴 👌 🤌 🤏 ✌️ 🤞
    print:emoji:line 🫰 🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝️ 🫵 👍 👎 ✊
    print:emoji:line 👊 🤛 🤜 👏 🙌 🫶 👐 🤲 🤝 🙏 ✍️ 💅 🤳

    # People & Body Parts
    print:category "👤 People & Body"
    print:emoji:line 💪 🦾 🦿 🦵 🦶 👂 🦻 👃 🧠 🫀 🫁 🦷 🦴 👀
    print:emoji:line 👁️ 👅 👄 🫦 💋 👶 🧒 👦 👧 🧑 👱 👨 🧔 👩
    print:emoji:line 🧓 👴 👵 🙍 🙎 🙅 🙆 💁 🙋 🧏 🙇 🤦 🤷 👮

    # Animals & Nature
    print:category "🐶 Animals & Nature"
    print:emoji:line 🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐽
    print:emoji:line 🐸 🐵 🙈 🙉 🙊 🐒 🐔 🐧 🐦 🐤 🐣 🐥 🦆 🦅
    print:emoji:line 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🪱 🐛 🦋 🐌 🐞 🐜 🪰
    print:emoji:line 🪲 🦟 🦗 🕷️ 🕸️ 🦂 🐢 🐍 🦎 🦖 🦕 🐙 🦑 🦐
    print:emoji:line 🦞 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🐅 🐆 🦓 🦍
    print:emoji:line 🦧 🦣 🐘 🦛 🦏 🐪 🐫 🦒 🦘 🦬 🐃 🐂 🐄 🐎
    print:emoji:line 🐖 🐏 🐑 🦙 🐐 🦌 🐕 🐩 🦮 🐕‍🦺 🐈 🐈‍⬛ 🪶 🐓
    print:emoji:line 🦃 🦤 🦚 🦜 🦢 🦩 🕊️ 🐇 🦝 🦨 🦡 🦫 🦦 🦥
    print:emoji:line 🐁 🐀 🐿️ 🦔 🐾 🐉 🐲 🌵 🎄 🌲 🌳 🌴 🪵 🌱
    print:emoji:line 🌿 ☘️ 🍀 🎍 🪴 🎋 🍃 🍂 🍁 🍄 🐚 🪨 🌾 💐
    print:emoji:line 🌷 🌹 🥀 🪷 🪻 🌺 🌸 🌼 🌻 🌞 🌝 🌛 🌜 🌚
    print:emoji:line 🌕 🌖 🌗 🌘 🌑 🌒 🌓 🌔 🌙 🌎 🌍 🌏 🪐 💫
    print:emoji:line ⭐ 🌟 ✨ ⚡ ☄️ 💥 🔥 🌪️ 🌈 ☀️ 🌤️ ⛅ 🌥️ ☁️
    print:emoji:line 🌦️ 🌧️ ⛈️ 🌩️ 🌨️ ❄️ ☃️ ⛄ 🌬️ 💨 💧 💦 ☔ ☂️

    # Food & Drink
    print:category "🍎 Food & Drink"
    print:emoji:line 🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭
    print:emoji:line 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶️ 🫑 🌽 🥕 🫒
    print:emoji:line 🧄 🧅 🥔 🍠 🥐 🥯 🍞 🥖 🥨 🧀 🥚 🍳 🧈 🥞
    print:emoji:line 🧇 🥓 🥩 🍗 🍖 🦴 🌭 🍔 🍟 🍕 🫓 🥪 🥙 🧆
    print:emoji:line 🌮 🌯 🫔 🥗 🥘 🫕 🥫 🍝 🍜 🍲 🍛 🍣 🍱 🥟
    print:emoji:line 🦪 🍤 🍙 🍚 🍘 🍥 🥠 🥮 🍢 🍡 🍧 🍨 🍦 🥧
    print:emoji:line 🧁 🍰 🎂 🍮 🍭 🍬 🍫 🍿 🍩 🍪 🌰 🥜 🍯 🥛
    print:emoji:line 🍼 🫖 ☕ 🍵 🧃 🥤 🧋 🍶 🍺 🍻 🥂 🍷 🥃 🍸
    print:emoji:line 🍹 🧉 🍾 🧊 🥄 🍴 🍽️ 🥣 🥡 🥢 🧂

    # Travel & Places
    print:category "🌍 Travel & Places"
    print:emoji:line 🚗 🚕 🚙 🚌 🚎 🏎️ 🚓 🚑 🚒 🚐 🛻 🚚 🚛 🚜
    print:emoji:line 🦯 🦽 🦼 🛴 🚲 🛵 🏍️ 🛺 🚨 🚔 🚍 🚘 🚖 🚡
    print:emoji:line 🚠 🚟 🚃 🚋 🚞 🚝 🚄 🚅 🚈 🚂 🚆 🚇 🚊 🚉
    print:emoji:line ✈️ 🛫 🛬 🛩️ 💺 🛰️ 🚀 🛸 🚁 🛶 ⛵ 🚤 🛥️ 🛳️
    print:emoji:line ⛴️ 🚢 ⚓ 🪝 ⛽ 🚧 🚦 🚥 🚏 🗺️ 🗿 🗽 🗼 🏰
    print:emoji:line 🏯 🏟️ 🎡 🎢 🎠 ⛲ ⛱️ 🏖️ 🏝️ 🏜️ 🌋 ⛰️ 🏔️ 🗻
    print:emoji:line 🏕️ ⛺ 🛖 🏠 🏡 🏘️ 🏚️ 🏗️ 🏭 🏢 🏬 🏣 🏤 🏥
    print:emoji:line 🏦 🏨 🏪 🏫 🏩 💒 🏛️ ⛪ 🕌 🕍 🛕 🕋 ⛩️ 🛤️

    # Activities & Sports
    print:category "⚽ Activities & Sports"
    print:emoji:line ⚽ 🏀 🏈 ⚾ 🥎 🎾 🏐 🏉 🥏 🎱 🪀 🏓 🏸 🏒
    print:emoji:line 🏑 🥍 🏏 🪃 🥅 ⛳ 🪁 🏹 🎣 🤿 🥊 🥋 🎽 🛹
    print:emoji:line 🛼 🛷 ⛸️ 🥌 🎿 ⛷️ 🏂 🪂 🏋️ 🤼 🤸 🤺 🤾 🏌️
    print:emoji:line 🏇 🧘 🏄 🏊 🤽 🚣 🧗 🚵 🚴 🏆 🥇 🥈 🥉 🏅
    print:emoji:line 🎖️ 🎗️ 🎫 🎟️ 🎪 🤹 🎭 🩰 🎨 🎬 🎤 🎧 🎼 🎹
    print:emoji:line 🥁 🪘 🎷 🎺 🪗 🎸 🪕 🎻 🎲 ♟️ 🎯 🎳 🎮 🎰 🧩

    # Objects
    print:category "💡 Objects"
    print:emoji:line ⌚ 📱 📲 💻 ⌨️ 🖥️ 🖨️ 🖱️ 🖲️ 🕹️ 🗜️ 💽 💾 💿
    print:emoji:line 📀 📼 📷 📸 📹 🎥 📽️ 🎞️ 📞 ☎️ 📟 📠 📺 📻
    print:emoji:line 🎙️ 🎚️ 🎛️ 🧭 ⏱️ ⏲️ ⏰ 🕰️ ⌛ ⏳ 📡 🔋 🔌 💡
    print:emoji:line 🔦 🕯️ 🪔 🧯 🛢️ 💸 💵 💴 💶 💷 🪙 💰 💳 🪪
    print:emoji:line 💎 ⚖️ 🪜 🧰 🪛 🔧 🔨 ⚒️ 🛠️ ⛏️ 🪚 🔩 ⚙️ 🪤
    print:emoji:line 🧱 ⛓️ 🧲 🔫 💣 🧨 🪓 🔪 🗡️ ⚔️ 🛡️ 🚬 ⚰️ 🪦
    print:emoji:line ⚱️ 🏺 🔮 📿 🧿 💈 ⚗️ 🔭 🔬 🕳️ 🩹 🩺 💊 💉
    print:emoji:line 🩸 🧬 🦠 🧫 🧪 🌡️ 🧹 🪠 🧺 🧻 🚽 🚰 🚿 🛁
    print:emoji:line 🛀 🧴 🧷 🧹 🧽 🧼 🪥 🪒 🧺 🧦 🧤 🧣 👓 🕶️
    print:emoji:line 🥽 🥼 🦺 👔 👕 👖 🧵 🪡 🧶 👗 👘 🥻 🩱 🩲
    print:emoji:line 🩳 👙 👚 👛 👜 👝 🛍️ 🎒 🩴 👞 👟 🥾 🥿 👠
    print:emoji:line 👡 🩰 👢 👑 👒 🎩 🎓 🧢 🪖 ⛑️ 📿 💄 💍 💎

    # Symbols
    print:category "🔣 Symbols & Signs"
    print:emoji:line ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 🔴 🟠 🟡 🟢 🔵
    print:emoji:line 🟣 🟤 ⚫ ⚪ 🟥 🟧 🟨 🟩 🟦 🟪 🟫 ⬛ ⬜ 🔶
    print:emoji:line 🔷 🔸 🔹 🔺 🔻 💠 🔘 🔳 🔲 ▪️ ▫️ ◾ ◽ ◼️
    print:emoji:line ◻️ 🟥 🟧 🟨 🟩 🟦 🟪 ⬛ ⬜ 🔈 🔇 🔉 🔊 📢
    print:emoji:line 📣 📯 🔔 🔕 🎵 🎶 🎼 🎧 📻 🎙️ 🎚️ 🎛️ 💬 💭
    print:emoji:line 🗯️ 💤 💢 💥 💫 💦 💨 🕳️ 👁️‍🗨️ 🗨️ 🗯️ 💭 🚨 💡
    print:emoji:line ✨ 🌟 💫 💥 💯 🔥 💧 💦 ☀️ 🌙 ⭐ ⚡ ⛅ ☁️
    print:emoji:line ❄️ ☃️ ☄️ ♠️ ♥️ ♦️ ♣️ 🃏 🎴 🀄 🎭 🎨 🧵 🪡

    # Arrows & Directions
    print:category "➡️ Arrows & Directions"
    print:emoji:line ⬆️ ↗️ ➡️ ↘️ ⬇️ ↙️ ⬅️ ↖️ ↕️ ↔️ ↩️ ↪️ ⤴️ ⤵️
    print:emoji:line 🔃 🔄 🔙 🔚 🔛 🔜 🔝 🛐 ⚛️ 🕉️ ✡️ ☸️ ☯️ ✝️
    print:emoji:line ☦️ ☪️ ☮️ 🕎 🔯 ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐
    print:emoji:line ♑ ♒ ♓ ⛎ 🔀 🔁 🔂 ▶️ ⏩ ⏭️ ⏯️ ◀️ ⏪ ⏮️
    print:emoji:line 🔼 ⏫ 🔽 ⏬ ⏸️ ⏹️ ⏺️ ⏏️ 🎦 🔅 🔆 📶 📳 📴

    # Math & Numbers
    print:category "🔢 Math & Numbers"
    print:emoji:line 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟 🔢 🔣 ➕
    print:emoji:line ➖ ✖️ ➗ 🟰 ♾️ ‼️ ⁉️ ❓ ❔ ❕ ❗ 〰️ ⚕️ ♻️
    print:emoji:line ⚜️ 🔱 📛 🔰 ⭕ ✅ ☑️ ✔️ ❌ ❎ ➰ ➿ 〽️ ✳️
    print:emoji:line ✴️ ❇️ © ® ™ 🔠 🔡 🔤 🅰️ 🆎 🅱️ 🆑 🆒 🆓

    # Flags (selection)
    print:category "🏁 Flags"
    print:emoji:line 🏁 🚩 🎌 🏴 🏳️ 🏳️‍🌈 🏳️‍⚧️ 🏴‍☠️ 🇺🇳 🇺🇸 🇬🇧 🇨🇦 🇦🇺 🇩🇪
    print:emoji:line 🇫🇷 🇪🇸 🇮🇹 🇯🇵 🇨🇳 🇰🇷 🇧🇷 🇮🇳 🇷🇺 🇺🇦
}

# Main execution
clear

# Detect terminal capabilities first
detect:terminal:capabilities
terminal_has_good_emoji=$?

report:emojis

echo:Emoji ""
echo:Hint "Hints:"
echo:Hint "  - Simply copy and paste the emoji you need from above"
echo:Hint "  - To copy: select the emoji with your mouse and use Ctrl+Shift+C (or Cmd+C on Mac)"
echo:Hint "  - To paste: use Ctrl+Shift+V (or Cmd+V on Mac)"
echo:Hint ""
echo:Hint "Terminal Compatibility:"
echo:Hint "  - Some emojis may not render correctly depending on your terminal and font"
echo:Hint "  - Newer emojis (Unicode 14+) require recent terminal emulators and fonts"
echo:Hint "  - Compound emojis (with ZWJ sequences) need advanced font support"
echo:Hint "  - Best support: iTerm2 (macOS), Windows Terminal, modern GNOME Terminal, Alacritty"
echo:Hint "  - Install Noto Color Emoji or Apple Color Emoji fonts for better rendering"
echo:Hint "  - If emojis show as boxes or [?], your terminal/font doesn't support them yet"
echo:Emoji ""
