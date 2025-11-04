#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-04
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

function print:category() {
    local category="$1"
    local reset=$(printf "\033[0m")
    local bold=$(printf "\033[1m")
    local cyan=$(printf "\033[36m")

    echo ""
    printf "%s%s%s%s\n" "$bold" "$cyan" "$category" "$reset"
}

function print:emoji:line() {
    local emojis=("$@")
    for emoji in "${emojis[@]}"; do
        printf " %s " "$emoji"
    done
    echo ""
}

function report:emojis() {
    # Smileys & Emotion
    print:category "😀 Smileys & Emotion"
    print:emoji:line 😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 🫠 😉 😊 😇
    print:emoji:line 🥰 😍 🤩 😘 😗 😚 😙 🥲 😋 😛 😜 🤪 😝 🤑
    print:emoji:line 🤗 🤭 🫢 🫣 🤫 🤔 🫡 🤐 🤨 😐 😑 😶 🫥 😏
    print:emoji:line 😒 🙄 😬 😮‍💨 🤥 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢
    print:emoji:line 🤮 🤧 🥵 🥶 😶‍🌫️ 😵 😵‍💫 🤯 🤠 🥳 🥸 😎 🤓 🧐
    print:emoji:line 😕 🫤 😟 🙁 😮 😯 😲 😳 🥺 🥹 😦 😧 😨 😰
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
report:emojis

echo ""
echo "Hints:"
echo "  - Simply copy and paste the emoji you need from above"
echo "  - Most modern terminals support emoji rendering"
echo "  - To copy: select the emoji with your mouse and use Ctrl+Shift+C (or Cmd+C on Mac)"
echo "  - To paste: use Ctrl+Shift+V (or Cmd+V on Mac)"
echo "  - If emojis don't display correctly, ensure your terminal supports UTF-8 encoding"
echo ""
