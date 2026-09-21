import type { HighlighterCore } from 'shiki/core'

// Shiki con motor JavaScript (sin WASM) y solo los lenguajes del
// catálogo: el resaltado pesa lo mínimo y va en el chunk del lector.
const LANGS = ['go', 'sql', 'bash', 'json', 'typescript', 'javascript', 'tsx', 'yaml', 'html', 'css'] as const
export type Lang = (typeof LANGS)[number]

// Tema Grafito: mismos tokens que la UI, fondo surface-1, sin colores
// fuera de la paleta. El caramelo se reserva para lo que el alumno mira
// (cadenas y valores), no para todo.
const grafito = {
  name: 'grafito',
  type: 'dark' as const,
  colors: { 'editor.background': '#1B1B1D', 'editor.foreground': '#EDEDEB' },
  settings: [
    { settings: { background: '#1B1B1D', foreground: '#EDEDEB' } },
    { scope: ['comment', 'punctuation.definition.comment'], settings: { foreground: '#8C8C8A', fontStyle: 'italic' } },
    { scope: ['string', 'constant.numeric', 'constant.language'], settings: { foreground: '#E08E33' } },
    { scope: ['keyword', 'storage', 'storage.type', 'keyword.control'], settings: { foreground: '#9A9A97' } },
    { scope: ['entity.name.function', 'support.function', 'meta.function-call'], settings: { foreground: '#EDEDEB' } },
    { scope: ['entity.name.type', 'support.type', 'entity.name.class'], settings: { foreground: '#EDA04D' } },
    { scope: ['variable', 'variable.other', 'meta.definition.variable'], settings: { foreground: '#EDEDEB' } },
    { scope: ['punctuation', 'meta.brace'], settings: { foreground: '#9A9A97' } },
  ],
}

let highlighter: Promise<HighlighterCore> | null = null

function load(): Promise<HighlighterCore> {
  highlighter ??= (async () => {
    const [{ createHighlighterCore }, { createJavaScriptRegexEngine }] = await Promise.all([
      import('shiki/core'),
      import('shiki/engine/javascript'),
    ])
    return createHighlighterCore({
      themes: [grafito],
      langs: [
        import('shiki/langs/go.mjs'),
        import('shiki/langs/sql.mjs'),
        import('shiki/langs/bash.mjs'),
        import('shiki/langs/json.mjs'),
        import('shiki/langs/typescript.mjs'),
        import('shiki/langs/javascript.mjs'),
        import('shiki/langs/tsx.mjs'),
        import('shiki/langs/yaml.mjs'),
        import('shiki/langs/html.mjs'),
        import('shiki/langs/css.mjs'),
      ],
      engine: createJavaScriptRegexEngine(),
    })
  })()
  return highlighter
}

function normalize(lang?: string): Lang | null {
  if (!lang) return null
  const l = lang.toLowerCase()
  const alias: Record<string, Lang> = { sh: 'bash', shell: 'bash', ts: 'typescript', js: 'javascript', yml: 'yaml', golang: 'go' }
  const resolved = (alias[l] ?? l) as Lang
  return (LANGS as readonly string[]).includes(resolved) ? resolved : null
}

/** Devuelve HTML resaltado, o null si el lenguaje no está soportado. */
export async function highlight(code: string, lang?: string): Promise<string | null> {
  const resolved = normalize(lang)
  if (!resolved) return null
  try {
    const hl = await load()
    return hl.codeToHtml(code, { lang: resolved, theme: 'grafito' })
  } catch {
    return null
  }
}
