import { defineConfig, type Plugin } from 'vite'
import { TanStackRouterVite } from '@tanstack/router-plugin/vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import ts from 'typescript'

const runtimeEnvironment = (globalThis as typeof globalThis & {
  process?: { env?: Record<string, string | undefined> }
}).process?.env ?? {}

function isImportMeta(node: ts.Expression): boolean {
  return ts.isMetaProperty(node) &&
    node.keywordToken === ts.SyntaxKind.ImportKeyword &&
    node.name.text === 'meta'
}

function isImportMetaEnv(node: ts.Expression): boolean {
  return ts.isPropertyAccessExpression(node) &&
    node.name.text === 'env' &&
    isImportMeta(node.expression)
}

function isProcessEnv(node: ts.Expression): boolean {
  return ts.isPropertyAccessExpression(node) &&
    node.name.text === 'env' &&
    ts.isIdentifier(node.expression) &&
    node.expression.text === 'process'
}

function toExpression(value: string | boolean | undefined): ts.Expression {
  if (typeof value === 'string') return ts.factory.createStringLiteral(value)
  if (typeof value === 'boolean') return value ? ts.factory.createTrue() : ts.factory.createFalse()
  return ts.factory.createIdentifier('undefined')
}

function cleanDefineComments(code: string): string {
  const scanner = ts.createScanner(
    ts.ScriptTarget.Latest,
    false,
    ts.LanguageVariant.JSX,
    code,
  )
  const edits: Array<{ start: number; end: number; text: string }> = []

  while (scanner.scan() !== ts.SyntaxKind.EndOfFileToken) {
    const kind = scanner.getToken()
    if (kind !== ts.SyntaxKind.SingleLineCommentTrivia && kind !== ts.SyntaxKind.MultiLineCommentTrivia) {
      continue
    }

    const text = scanner.getTokenText()
      .replaceAll('import.meta.env', 'import meta env')
      .replaceAll('import.meta.hot', 'import meta hot')
      .replaceAll('process.env', 'process env')
    const start = scanner.getTokenPos()
    if (text !== scanner.getTokenText()) edits.push({ start, end: scanner.getTextPos(), text })
  }

  return edits.reduceRight((result, edit) =>
    result.slice(0, edit.start) + edit.text + result.slice(edit.end), code)
}

function loongarchTypeScriptPlugin(): Plugin {
  let defineValues: Record<string, string | boolean> = {}
  let nodeEnv = 'production'

  return {
    name: 'loongarch-typescript',
    enforce: 'pre',
    configResolved(config) {
      nodeEnv = runtimeEnvironment.NODE_ENV || config.mode
      defineValues = {
        ...config.env,
        BASE_URL: config.base,
        MODE: config.mode,
        DEV: config.mode !== 'production',
        PROD: config.mode === 'production',
        SSR: false,
      }
    },
    transform(code, id) {
      const fileName = id.split('?', 1)[0]
      if (!/\.[cm]?[jt]sx?$/.test(fileName)) return null

      const isTypeScript = /\.[cm]?tsx?$/.test(fileName)
      if (!isTypeScript && !/(?:process\.env|import\.meta\.(?:env|hot))/.test(code)) return null

      const result = ts.transpileModule(code, {
        fileName,
        compilerOptions: {
          allowJs: true,
          checkJs: false,
          jsx: ts.JsxEmit.ReactJSX,
          jsxImportSource: 'react',
          module: ts.ModuleKind.ESNext,
          noEmit: false,
          sourceMap: true,
          target: ts.ScriptTarget.ESNext,
          verbatimModuleSyntax: true,
        },
        transformers: {
          before: [context => sourceFile => {
            const visit: ts.Visitor = node => {
              if (ts.isPropertyAccessExpression(node)) {
                if (node.name.text === 'NODE_ENV' && isProcessEnv(node.expression)) {
                  return ts.factory.createStringLiteral(nodeEnv)
                }
                if (isProcessEnv(node)) return ts.factory.createObjectLiteralExpression()
                if (isImportMetaEnv(node.expression)) {
                  return toExpression(defineValues[node.name.text])
                }
                if (isImportMetaEnv(node)) {
                  return ts.factory.createObjectLiteralExpression(
                    Object.entries(defineValues).map(([key, value]) =>
                      ts.factory.createPropertyAssignment(ts.factory.createStringLiteral(key), toExpression(value))),
                  )
                }
                if (node.name.text === 'hot' && isImportMeta(node.expression)) {
                  return ts.factory.createIdentifier('undefined')
                }
              }
              return ts.visitEachChild(node, visit, context)
            }

            return ts.visitNode(sourceFile, visit) as ts.SourceFile
          }],
        },
      })
      return {
        code: cleanDefineComments(result.outputText),
        map: result.sourceMapText ? JSON.parse(result.sourceMapText) : null,
      }
    },
  }
}

function loongarchDisableEsbuildPlugin(): Plugin {
  return {
    name: 'loongarch-disable-esbuild',
    enforce: 'post',
    config() {
      return { esbuild: false }
    },
    async closeBundle() {
      type EsbuildRequire = ((specifier: string) => { stop(): Promise<void> }) & {
        resolve(specifier: string): string
      }
      type NodeModuleApi = { createRequire(filename: string | URL): EsbuildRequire }
      const nodeProcess = (globalThis as typeof globalThis & {
        process?: { getBuiltinModule?: (specifier: string) => unknown }
      }).process
      if (!nodeProcess?.getBuiltinModule) throw new Error('Node module API 不可用。')

      const moduleApi = nodeProcess.getBuiltinModule('module') as NodeModuleApi
      const requireFromConfig = moduleApi.createRequire(import.meta.url)
      const requireFromVite = moduleApi.createRequire(requireFromConfig.resolve('vite'))
      await requireFromVite('esbuild').stop()
    },
  }
}

/**
 * Make Vite build output compatible with file:// protocol:
 * 1. Move <script> tags from <head> to end of <body> (DOM must be ready for React)
 * 2. Strip crossorigin attribute from all tags (blocked under file://)
 * 3. Strip type="module" from scripts (IIFE bundles don't need it)
 */
function fileProtocolCompat(): Plugin {
  return {
    name: 'file-protocol-compat',
    enforce: 'post',
    transformIndexHtml(html) {
      // 1) Strip crossorigin from all tags (link, script, etc.)
      let result = html.replace(/ crossorigin/g, '')

      // 2) Move <script> from <head> to end of <body>
      const headEnd = result.indexOf('</head>')
      const scriptRe = /<script\b[^>]*src="[^"]*"[^>]*><\/script>/g
      const scripts: string[] = []
      result = result.replace(scriptRe, (match, offset) => {
        if (offset < headEnd) {
          scripts.push(match)
          return ''
        }
        return match
      })

      if (scripts.length > 0) {
        // 3) Strip type="module" for IIFE bundles
        const cleaned = scripts.map(s => s.replace(/ type="module"/, ''))
        result = result.replace('</body>', '    ' + cleaned.join('\n    ') + '\n  </body>')
      }

      return result
    }
  }
}

// https://vite.dev/config/
export default defineConfig({
  base: './',
  plugins: [
    TanStackRouterVite({
      target: 'react',

      // IMPORTANT: false only for development debugging!!!! 【true for production】
      autoCodeSplitting: false
    }),
    ...(runtimeEnvironment.BAMBU_STUDIO_LOONGARCH_BUILD === '1'
      ? [loongarchTypeScriptPlugin(), loongarchDisableEsbuildPlugin()]
      : []),
    react(),
    tailwindcss(),
    fileProtocolCompat(),
  ],

  esbuild: runtimeEnvironment.BAMBU_STUDIO_LOONGARCH_BUILD === '1' ? false : undefined,

  resolve: {
    alias: {
      '@locales': new URL('./locales', import.meta.url).href,
    },
  },

  build: {
    // Keep in step with package.json browserslist; unset lets Vite's default drift.
    target: ['chrome111', 'edge111', 'safari16.4'],
    cssTarget: ['chrome111', 'edge111', 'safari16.4'],
    cssMinify: runtimeEnvironment.BAMBU_STUDIO_LOONGARCH_BUILD === '1' ? false : undefined,
    // Debug: emit `assets/index.js.map` so Chrome DevTools can
    // attach to the live WebView2 over CDP and let the developer set
    // source-level breakpoints inside .ts source. This adds ~1MB to dist/
    // (gzipped only when served compressed) but does NOT affect the
    // shipped runtime — the bundle stays minified, the .map file is
    // requested on demand only when DevTools is open. Flip back to false
    // before tagging a release if the size matters.
    sourcemap: true,
    rollupOptions: {
      output: {
        // fileProtocolCompat() strips type="module"; IIFE is required for file://.
        format: 'iife',
        name: 'DevicePageApp',
        inlineDynamicImports: true,
        entryFileNames: 'assets/[name].js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name].[ext]'
      }
    },
    // Use terser instead of esbuild so we can reserve the name "wx".
    // WKWebView's AddScriptMessageHandler("wx") injects `window.wx` as a
    // UserMessageHandler instance. If the minifier generates a top-level
    // variable called "wx", it shadows the global and causes:
    // "wx is not a function (it is an instance of UserMessageHandler)".
    minify: 'terser',
    terserOptions: {
      mangle: {
        reserved: ['wx'],
      },
    },
  }
})
