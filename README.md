# PDF 转 Markdown (MinerU)

基于 [MinerU](https://github.com/opendatalab/MinerU) 的 PDF 转 Markdown 工具，开箱即用。

## 🚀 使用

**双击 `启动PDF转MD.bat`**：
1. 把 PDF 文件拖进窗口
2. 回车
3. 等待转换完成，自动打开输出文件夹

## ⌨️ 命令行

```bash
# 基本用法
./pdf2md.sh <PDF路径> -b pipeline

# 示例
./pdf2md.sh 合同.pdf -b pipeline
./pdf2md.sh 起诉状.pdf -m ocr -b pipeline
```

## 📁 输出

```
PDF转MD/output/<文件名>/<文件名>/auto/
├── xxx.md          # Markdown 文件
├── xxx_middle.json # 中间数据
└── xxx_layout.pdf  # 版面分析
```

## ⚙️ 参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 解析方式: auto / txt / ocr | auto |
| `-b` | 后端引擎: pipeline / hybrid-auto-engine | pipeline |
| `-l` | 语言: ch / en / japan / korean | ch |
| `-s` | 起始页 (从0开始) | 0 |
| `-e` | 结束页 | 末页 |

## 🔧 依赖

- [MinerU](https://github.com/opendatalab/MinerU) (已内置于 `../mineru-env/`)
- Python 3.12+
