# 文档转 Markdown

基于 [MinerU](https://github.com/opendatalab/MinerU)，一键把文档转成 Markdown。

**支持格式**：PDF · DOCX · PPTX · XLSX · PNG · JPG · BMP 等图片

## 🚀 使用

**双击 `启动文档转MD.bat`**：
- 拖入一个文件 → 自动转换
- 拖入一个文件夹 → 扫描所有支持的文件，按原目录结构全部转换
- 完成后自动打开输出文件夹

## ⌨️ 命令行

```bash
# 单文件
./pdf2md.sh 合同.pdf -b pipeline

# 整个文件夹（保持目录结构）
./pdf2md.sh 证据材料/ -b pipeline
```

## 📁 输出

**单文件**：
```
output/<文件名>/<文件名>/auto/<文件名>.md
```

**文件夹**（拖入 `材料/`，内含 `合同.docx` 和 `证据/扫描件.pdf`）：
```
output/材料/
├── 合同/合同/auto/合同.md
└── 证据/扫描件/扫描件/auto/扫描件.md
```

## ⚙️ 参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-b` | 后端: pipeline / hybrid-auto-engine | pipeline |
| `-l` | 语言: ch / en / japan / korean | ch |
| `-m` | 解析: auto / txt / ocr | auto |

## 🔧 依赖

- [MinerU](https://github.com/opendatalab/MinerU)（`../mineru-env/`）
- Python 3.12+
