#!/bin/bash

# Panodaki verinin tipini doğrudan içeriğinden kontrol et
# Bu yöntem, pano yöneticisinin (clipse vb.) tipi yanlış raporladığı durumlarda bile çalışır.
MIME_TYPE=$(wl-paste | file -b --mime-type - 2> /dev/null)
IMAGE_PATH=""
IS_IMAGE=false

if [[ "$MIME_TYPE" == image/* ]]; then
        IMAGE_PATH="/tmp/translate_clip_$(date +%s).png"
        wl-paste > "$IMAGE_PATH" 2> /dev/null
        # Dosya gerçekten oluştu mu ve dolu mu kontrol et
        if [ -s "$IMAGE_PATH" ]; then
                IS_IMAGE=true
        fi
fi

# Eğer resim değilse, metin olarak al (geleneksel yöntem)
TEXT_CONTENT=$(wl-paste 2> /dev/null)

clear

if [ "$IS_IMAGE" = true ]; then
        # RESİM ÇEVİRİ AKIŞI
        prompt="You are an AI translator. Detect all text in the attached image and translate it. Don't act as a human, NO comments, don't write your thoughts. Format:

Original ([LANG]): [Extracted text from image]
🇬🇧: [translation]
🇩🇪: [translation]
🇹🇷: [translation]

NO comments."

        echo "🔄 Detected IMAGE (Mime: $MIME_TYPE)"
        echo "🔄 OCR & Translating..."
        echo ""

        result=$(opencode run "$prompt" --agent plan --model google/antigravity-gemini-3-flash -f "$IMAGE_PATH")

        # Temizlik
        rm -f "$IMAGE_PATH"
else
        # METİN ÇEVİRİ AKIŞI
        [ -z "$TEXT_CONTENT" ] && {
                echo "❌ Empty clipboard!"
                sleep 2
                exit 1
        }

        word_count=$(echo "$TEXT_CONTENT" | wc -w)

        if [ "$word_count" -le 3 ]; then
                prompt="You are an AI translator. Don't act as a human, Translate and define, NO comments, don't write your thoughts, don't use Web Search(research) etc. Format:

Original ([LANG]): $TEXT_CONTENT
🇬🇧: [translation]
🇩🇪: [translation]
🇹🇷: [translation]

🇩🇪 Definition: [detailed German definition with examples]

NO comments. "
        else
                prompt="Translate. Format:

Original ([LANG]): $TEXT_CONTENT
🇬🇧: [translation]
🇩🇪: [translation]
🇹🇷: [translation]

NO comments. "
        fi

        echo "🔄 Detected TEXT ($word_count words)"
        echo "🔄 Translating..."
        echo ""
        result=$(opencode run --agent plan --model google/antigravity-gemini-3-flash "$prompt")
fi

# Sonucu Göster
echo "$result"

# Kaydet
WIKI="$HOME/vimwiki/translations.md"
mkdir -p "$(dirname "$WIKI")"
{
        echo ""
        echo "== $(date '+%Y-%m-%d %H:%M:%S') =="
        echo "$result"
        echo "---"
} >> "$WIKI"

# Cleanup (Opencode session logs)
sleep 0.5
SESSION_DIR="$HOME/.local/share/opencode/storage/session/global"
LATEST=$(ls -t "$SESSION_DIR"/*.json 2> /dev/null | head -1)
if [ -n "$LATEST" ]; then
        SID=$(basename "$LATEST" .json)
        rm -f "$LATEST"
        rm -rf "$HOME/.local/share/opencode/storage/message/$SID"
        rm -f "$HOME/.local/share/opencode/storage/session_diff/${SID}.json"
fi

echo ""
read -p "Press Enter to close..."
