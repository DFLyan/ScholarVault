export enum CitationFormat {
  BIBTEX = 0,
  APA = 1,
  MLA = 2,
  RIS = 3
}

export class CitationFormatHelper {
  static getLabel(format: CitationFormat): string {
    if (format === CitationFormat.BIBTEX) {
      return 'BibTeX'
    }
    if (format === CitationFormat.APA) {
      return 'APA'
    }
    if (format === CitationFormat.MLA) {
      return 'MLA'
    }
    return 'RIS'
  }

  static getFileExtension(format: CitationFormat): string {
    if (format === CitationFormat.BIBTEX) {
      return '.bib'
    }
    if (format === CitationFormat.RIS) {
      return '.ris'
    }
    return '.txt'
  }
}
