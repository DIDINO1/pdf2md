#!/usr/bin/env bash
# ============================================================
#  文档转 Markdown 脚本（MinerU 封装）
#  支持: PDF / DOCX / PPTX / XLSX / 图片
# ============================================================
# 用法:
#   ./pdf2md.sh <文件或文件夹路径> [选项]
#
# 示例:
#   ./pdf2md.sh 合同.docx -b pipeline
#   ./pdf2md.sh 证据材料/ -b pipeline
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MINERU_PYTHON="$WORKSPACE_DIR/mineru-env/Scripts/python.exe"
OUTPUT_BASE="$SCRIPT_DIR/output"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SUPPORTED_EXTS=("pdf" "docx" "pptx" "xlsx" "png" "jpg" "jpeg" "bmp" "tiff" "tif" "gif" "webp")

print_usage() {
    echo "============================================"
    echo "  Document -> Markdown (MinerU)"
    echo "============================================"
    echo ""
    echo "用法: $0 <文件或文件夹路径> [选项]"
    echo ""
    echo "支持格式: PDF, DOCX, PPTX, XLSX, 图片"
    echo ""
    echo "可选参数:"
    echo "  -b, --backend <BK>  后端: pipeline(默认) / hybrid-auto-engine"
    echo "  -l, --lang <LANG>   语言: ch(默认) / en / japan / korean"
    echo "  -m, --method <M>    解析: auto(默认) / txt / ocr"
    echo "  -o, --output <DIR>  自定义输出目录"
    echo "  -h, --help          帮助"
    echo ""
}

if [ ! -f "$MINERU_PYTHON" ]; then
    echo -e "${RED}[ERROR] MinerU Python not found: $MINERU_PYTHON${NC}"
    exit 1
fi

INPUT_PATH=""
OUTPUT_DIR=""
BACKEND="pipeline"
LANG="ch"
METHOD="auto"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) print_usage; exit 0 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -m|--method) METHOD="$2"; shift 2 ;;
        -l|--lang) LANG="$2"; shift 2 ;;
        -b|--backend) BACKEND="$2"; shift 2 ;;
        -*) echo -e "${RED}Unknown: $1${NC}"; print_usage; exit 1 ;;
        *) INPUT_PATH="$1"; shift ;;
    esac
done

if [ -z "$INPUT_PATH" ]; then
    echo -e "${RED}[ERROR] Please provide a file or folder path${NC}"
    print_usage
    exit 1
fi

INPUT_PATH="$(realpath "$INPUT_PATH" 2>/dev/null || readlink -f "$INPUT_PATH" 2>/dev/null || echo "$INPUT_PATH")"

if [ ! -e "$INPUT_PATH" ]; then
    echo -e "${RED}[ERROR] Path not found: $INPUT_PATH${NC}"
    exit 1
fi

convert_file() {
    local input="$1"
    local output="$2"
    local stem="$3"

    echo -e "  ${CYAN}[*]${NC} $stem"

    mkdir -p "$output"
    "$MINERU_PYTHON" -c "from mineru.cli.client import main; main()" \
        -p "$input" -o "$output" \
        -m "$METHOD" -b "$BACKEND" -l "$LANG" \
        -f true -t true --image-analysis true > /dev/null 2>&1
}

if [ -d "$INPUT_PATH" ]; then
    # ---- Folder mode ----
    FOLDER_NAME="$(basename "$INPUT_PATH")"
    echo ""
    echo -e "${CYAN}[Folder]${NC} $FOLDER_NAME"
    echo ""

    # Collect all supported files
    FILES=()
    for ext in "${SUPPORTED_EXTS[@]}"; do
        while IFS= read -r f; do
            [ -n "$f" ] && FILES+=("$f")
        done < <(find "$INPUT_PATH" -type f -iname "*.$ext" 2>/dev/null || true)
    done

    TOTAL=${#FILES[@]}
    if [ "$TOTAL" -eq 0 ]; then
        echo -e "${YELLOW}No supported files found.${NC}"
        echo "Supported: PDF, DOCX, PPTX, XLSX, images"
        exit 0
    fi

    echo -e "  Found ${GREEN}$TOTAL${NC} file(s)"
    echo ""

    COUNT=0
    FAILED=0
    for f in "${FILES[@]}"; do
        COUNT=$((COUNT + 1))
        STEM="$(basename "$f")"
        STEM="${STEM%.*}"

        # Relative path from input folder
        REL="${f#$INPUT_PATH/}"
        REL_DIR="$(dirname "$REL")"

        if [ "$REL_DIR" = "." ]; then
            OUT_DIR="$OUTPUT_BASE/$FOLDER_NAME"
        else
            OUT_DIR="$OUTPUT_BASE/$FOLDER_NAME/$REL_DIR"
        fi

        echo -ne "  [$COUNT/$TOTAL] "
        if convert_file "$f" "$OUT_DIR" "$STEM"; then
            :
        else
            FAILED=$((FAILED + 1))
        fi
    done

    echo ""
    echo -e "${GREEN}Done!${NC} $((TOTAL - FAILED))/$TOTAL converted."
    [ "$FAILED" -gt 0 ] && echo -e "${RED}$FAILED failed.${NC}"

else
    # ---- Single file mode ----
    STEM="$(basename "$INPUT_PATH")"
    STEM="${STEM%.*}"

    if [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="$OUTPUT_BASE/$STEM"
    fi

    echo ""
    echo -e "  ${CYAN}File:${NC} $(basename "$INPUT_PATH")"
    echo -e "  ${CYAN}Output:${NC} $OUTPUT_DIR"
    echo ""

    convert_file "$INPUT_PATH" "$OUTPUT_DIR" "$STEM"
    echo ""
    echo -e "${GREEN}Done!${NC}"
fi

echo -e "  ${CYAN}Output base:${NC} $OUTPUT_BASE"
python "C:/Users/28793/.claude/hooks/notify-done.py" 2>/dev/null || true
