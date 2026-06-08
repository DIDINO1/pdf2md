#!/usr/bin/env bash
# ============================================================
# PDF 转 Markdown 脚本（MinerU 封装）
# ============================================================
# 用法：
#   ./pdf2md.sh <PDF文件路径> [选项]
#
# 示例：
#   ./pdf2md.sh /d/合同/买卖合同.pdf
#   ./pdf2md.sh /d/合同/买卖合同.pdf -l en
#   ./pdf2md.sh /d/合同/买卖合同.pdf -m ocr -s 1 -e 10
#
# 输出位置：PDF转MD/output/<PDF文件名>/<PDF文件名>.md
# ============================================================

set -euo pipefail

# ---------- 路径配置 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MINERU_VENV_PYTHON="$WORKSPACE_DIR/mineru-env/Scripts/python.exe"
OUTPUT_BASE_DIR="$SCRIPT_DIR/output"

# ---------- 颜色 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_usage() {
    echo "============================================"
    echo "  PDF → Markdown 转换工具 (MinerU)"
    echo "============================================"
    echo ""
    echo "用法: $0 <PDF文件路径> [选项]"
    echo ""
    echo "必备参数:"
    echo "  <PDF文件路径>          要转换的 PDF 文件路径"
    echo ""
    echo "可选参数:"
    echo "  -m, --method <METHOD>  解析方式: auto(默认) / txt / ocr"
    echo "  -l, --lang <LANG>      文档语言: ch(默认) / en / ..."
    echo "  -b, --backend <BK>     后端引擎: hybrid-auto-engine(默认)"
    echo "  -s, --start <N>        起始页码 (从0开始, 默认0)"
    echo "  -e, --end <N>          结束页码 (从0开始)"
    echo "  --no-formula           禁用公式解析"
    echo "  --no-table             禁用表格解析"
    echo "  --no-image-analysis    禁用图片/图表分析"
    echo "  -o, --output <DIR>     自定义输出目录 (默认: PDF转MD/output/)"
    echo "  -h, --help             显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 买卖合同.pdf"
    echo "  $0 买卖合同.pdf -l en"
    echo "  $0 买卖合同.pdf -m ocr -b pipeline"
    echo "  $0 买卖合同.pdf -s 0 -e 5"
    echo ""
}

# ---------- 检查依赖 ----------
if [ ! -f "$MINERU_VENV_PYTHON" ]; then
    echo -e "${RED}❌ 找不到 MinerU Python: $MINERU_VENV_PYTHON${NC}"
    echo "请确认 mineru-env 虚拟环境存在于工作区根目录。"
    exit 1
fi

# ---------- 解析参数 ----------
PDF_PATH=""
OUTPUT_DIR=""
METHOD="auto"
LANG="ch"
BACKEND="hybrid-auto-engine"
START_PAGE=""
END_PAGE=""
FORMULA="true"
TABLE="true"
IMAGE_ANALYSIS="true"

# 收集所有非 - 开头的参数作为 PDF 路径候选
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -m|--method)
            METHOD="$2"
            shift 2
            ;;
        -l|--lang)
            LANG="$2"
            shift 2
            ;;
        -b|--backend)
            BACKEND="$2"
            shift 2
            ;;
        -s|--start)
            START_PAGE="$2"
            shift 2
            ;;
        -e|--end)
            END_PAGE="$2"
            shift 2
            ;;
        --no-formula)
            FORMULA="false"
            shift
            ;;
        --no-table)
            TABLE="false"
            shift
            ;;
        --no-image-analysis)
            IMAGE_ANALYSIS="false"
            shift
            ;;
        -*)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            print_usage
            exit 1
            ;;
        *)
            if [ -z "$PDF_PATH" ]; then
                PDF_PATH="$1"
            fi
            shift
            ;;
    esac
done

# ---------- 校验 PDF 路径 ----------
if [ -z "$PDF_PATH" ]; then
    echo -e "${RED}❌ 请提供 PDF 文件路径${NC}"
    print_usage
    exit 1
fi

# 转换为绝对路径（支持 Windows 路径）
PDF_PATH="$(realpath "$PDF_PATH" 2>/dev/null || readlink -f "$PDF_PATH" 2>/dev/null || echo "$PDF_PATH")"

if [ ! -f "$PDF_PATH" ]; then
    echo -e "${RED}❌ PDF 文件不存在: $PDF_PATH${NC}"
    exit 1
fi

# ---------- 确定输出目录 ----------
PDF_BASENAME="$(basename "$PDF_PATH" .pdf)"
PDF_BASENAME="$(basename "$PDF_BASENAME" .PDF)"

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$OUTPUT_BASE_DIR/$PDF_BASENAME"
fi

mkdir -p "$OUTPUT_DIR"

# ---------- 显示转换信息 ----------
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   PDF → Markdown (MinerU)               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  📄 输入文件: ${YELLOW}$PDF_PATH${NC}"
echo -e "  📁 输出目录: ${YELLOW}$OUTPUT_DIR${NC}"
echo -e "  ⚙️  后端引擎: ${GREEN}$BACKEND${NC}"
echo -e "  ⚙️  解析方式: ${GREEN}$METHOD${NC}"
echo -e "  🌐 文档语言: ${GREEN}$LANG${NC}"
[ -n "$START_PAGE" ] && echo -e "  📖 起始页码: ${GREEN}$START_PAGE${NC}"
[ -n "$END_PAGE" ] && echo -e "  📖 结束页码: ${GREEN}$END_PAGE${NC}"
echo ""

# ---------- 构建 MinerU 命令 ----------
MINERU_ARGS=(
    "-p" "$PDF_PATH"
    "-o" "$OUTPUT_DIR"
    "-m" "$METHOD"
    "-b" "$BACKEND"
    "-l" "$LANG"
    "-f" "$FORMULA"
    "-t" "$TABLE"
    "--image-analysis" "$IMAGE_ANALYSIS"
)

if [ -n "$START_PAGE" ]; then
    MINERU_ARGS+=("-s" "$START_PAGE")
fi
if [ -n "$END_PAGE" ]; then
    MINERU_ARGS+=("-e" "$END_PAGE")
fi

# ---------- 执行转换 ----------
echo -e "${YELLOW}⏳ 正在转换中，请稍候...${NC}"
echo ""

START_TIME=$(date +%s)

"$MINERU_VENV_PYTHON" -c "from mineru.cli.client import main; main()" "${MINERU_ARGS[@]}"
EXIT_CODE=$?

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ 转换完成！                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ⏱️  耗时: ${YELLOW}${ELAPSED} 秒${NC}"
    echo -e "  📁 输出目录: ${YELLOW}$OUTPUT_DIR${NC}"
    echo ""
    # 查找生成的 .md 文件（可能在嵌套子目录中）
    MD_FILE=$(find "$OUTPUT_DIR" -name "*.md" -type f 2>/dev/null | head -1)
    if [ -n "$MD_FILE" ]; then
        echo -e "  📝 Markdown 文件: ${CYAN}$MD_FILE${NC}"
    else
        echo -e "  📝 输出文件请见: ${CYAN}$OUTPUT_DIR${NC}"
    fi
    echo ""

    # 发送系统通知
    python "C:/Users/28793/.claude/hooks/notify-done.py" 2>/dev/null || true
else
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
    echo -e "${RED}║   ❌ 转换失败 (退出码: $EXIT_CODE)        ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════╝${NC}"
fi

exit $EXIT_CODE
