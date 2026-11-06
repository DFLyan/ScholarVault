# ScholarVault

一款自制的 HarmonyOS 文献管理应用，帮助研究人员和学生高效管理、阅读和引用学术文献。

## 功能特性

### 论文库管理
- 论文增删改查，支持标题、作者、年份、期刊、DOI、arXiv ID、摘要、关键词等元数据
- 通过 DOI / arXiv ID 自动抓取元数据（CrossRef / arXiv API）
- PDF 附件管理，手动选择或浏览器下载自动入库
- 阅读状态（未读 / 在读 / 已读）、5 星评分、收藏、置顶
- 多维度排序（添加时间 / 年份 / 标题 / 最近阅读 / 评分 / 自定义）与筛选（状态 / 收藏）
- 自定义排序下长按拖拽调整论文位置，顺序持久化保存
- 批量选择删除、左滑快捷删除
- 文件夹与标签双维度分类
- 沉浸式底部浮动 dock 导航（毛玻璃 + 阴影）

### PDF 阅读器
- 基于 PDFKit 的原生阅读体验，支持书签式续读（记忆上次阅读页码）
- 文本标注：高亮、下划线、删除线，4 种标注颜色
- 页内关键词搜索，搜索结果跳转
- 按页批注笔记，侧栏管理、点击跳页
- 阅读进度自动记录，读到末页自动标记为已读

### 文献检索与推荐
- 论文库元数据搜索 + PDF 全文检索（逐文档搜索，命中列表跳转对应页）
- 引用数自动获取（OpenAlex API）
- 相关文献推荐（Semantic Scholar API）
- 引用数一键刷新：按论文标题搜索 Semantic Scholar 候选结果，选择匹配项更新引用数并补全缺失的 DOI / 年份 / 期刊

### 账户同步
- Zotero 同步：配置用户 ID 与 API Key，拉取云端文献库自动入库（DOI / 标题去重）
- Mendeley / EndNote 暂无公开 API，可通过导出 .ris 文件在添加页导入

### 文档扫描
- 扫描本地 PDF / Word (.docx) / Excel (.xlsx) / TXT / Markdown 文档
- 通过论文标题匹配定位文档中包含的论文，PDF 标注所在页码

### 引用与导入导出
- 引用格式生成：BibTeX / APA / MLA / RIS
- 单篇或全库导出，支持复制到剪贴板、导出为文件
- BibTeX (.bib) / RIS (.ris) 文件批量导入，自动识别格式，DOI/标题重复自动跳过

### 其他
- 重复文献检测（按 DOI / 标题归组，一键清理）
- 统计面板：论文总数、收藏、PDF 附件、笔记数、阅读状态分布、年份分布柱状图、Top 期刊、Top 标签
- 内置学术网站浏览器（arXiv / Semantic Scholar / Google Scholar / CrossRef 快捷入口），下载 PDF 自动导入论文库

## 技术栈

- **框架**：HarmonyOS ArkTS / ArkUI（声明式 UI）
- **数据库**：关系型数据库（@ohos.data.relationalStore），支持 schema 版本迁移
- **PDF**：@kit.OfficeService PDFKit（PdfView + pdfService）
- **网络**：@ohos.net.http（CrossRef / arXiv / OpenAlex / Semantic Scholar / Zotero，均为免费公开 API）
- **状态管理**：V1 状态装饰器（@State / @Link / @Prop）
- **页面路由**：@ohos.router

## 环境要求

- DevEco Studio 5.0 及以上
- HarmonyOS SDK（compileSdkVersion 26 / targetSdk 26）
- HarmonyOS 真机或模拟器（需支持 PDFKit，API 12+）

## 构建与运行

```bash
# 安装依赖
ohpm install

# 构建
hvigorw assembleHap

# 或在 DevEco Studio 中直接 Run 到设备/模拟器
```

## 项目结构

```
entry/src/main/ets/
├── components/          # 通用组件（PaperCard、SearchBar、TagChip、EmptyState）
├── db/                  # 数据库层（DatabaseHelper：建表、迁移、CRUD、统计查询）
├── model/               # 数据模型（Paper、Category、PaperNote、ReaderNote、RouteParams 等）
├── pages/               # 页面
│   ├── MainPage         # 主页：论文库 / 分类 / 浏览器三个 Tab（浮动 dock、多选、拖拽排序）
│   ├── AddPaperPage     # 添加论文：DOI/arXiv、手动输入、文件导入
│   ├── PaperDetailPage  # 论文详情：状态/评分/笔记/引用/推荐/引用刷新
│   ├── PdfReaderPage    # PDF 阅读器：标注/批注/搜索/进度
│   ├── CitationExportPage # 引用导出
│   ├── StatisticsPage   # 统计面板
│   ├── DuplicatesPage   # 重复检测
│   ├── SyncSettingsPage # 账户同步（Zotero）
│   ├── DocumentScanPage # 文档扫描
│   └── CategoryManagePage # 分类管理
├── service/             # 业务服务
│   ├── PaperService     # 论文业务（含状态/进度/笔记/统计透传）
│   ├── MetadataFetcher  # DOI/arXiv 元数据抓取
│   ├── CitationService  # 引用格式生成（BibTeX/APA/MLA/RIS）
│   ├── ImportExportService # BibTeX/RIS 解析
│   ├── FullTextSearchService # PDF 全文检索
│   ├── DuplicateService # 重复检测
│   ├── ScholarService   # OpenAlex 引用数 + Semantic Scholar 推荐/搜索
│   ├── SyncService      # Zotero 同步（配置存储 + 拉取解析）
│   ├── DocumentScanService # 文档扫描（文本提取 + 标题匹配）
│   └── CategoryService  # 分类业务
└── entryability/        # Ability 入口
```

## 数据库 Schema

| 表 | 说明 |
| --- | --- |
| papers | 论文主表（含阅读状态、评分、收藏、置顶、引用数、阅读进度等字段） |
| categories | 分类（文件夹 / 标签） |
| paper_categories | 论文-分类关联 |
| paper_notes | 论文笔记 |
| pdf_annotations | PDF 批注笔记 |

## 许可证

[MIT](./LICENSE) © 2026 DFLyan
