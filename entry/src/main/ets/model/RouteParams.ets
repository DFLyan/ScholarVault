export interface PaperDetailParams {
  paperId: number
}

export interface PdfReaderParams {
  pdfPath: string
  paperTitle: string
  paperId: number
  initialPage: number
}

export interface CitationExportParams {
  paperId: number
}

export interface AddPaperResult {
  success: boolean
  paperId: number
}
