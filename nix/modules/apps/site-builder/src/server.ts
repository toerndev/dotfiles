import { spawn } from 'node:child_process'
import { statSync } from 'node:fs'
import { createServer } from 'node:http'
import type { IncomingMessage, ServerResponse } from 'node:http'
import { join } from 'node:path'

const HOST = process.env['WEBHOOK_HOST'] ?? '127.0.0.1'
const PORT = Number(process.env['WEBHOOK_PORT'] ?? '9055')
const DEBOUNCE_MS = Number(process.env['DEBOUNCE_MS'] ?? '10000')
const SECRET = process.env['WEBHOOK_SECRET'] ?? null

const PROJECTS_ROOT = '/srv'
const SCRIPT_PATH = 'scripts/build-and-deploy.sh'
const KEY_REGEX = /^[a-zA-Z0-9_-]+$/

const timers = new Map<string, ReturnType<typeof setTimeout>>()

function log(msg: string): void {
  console.log(`[${new Date().toISOString()}] ${msg}`)
}

function run(cwd: string): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const proc = spawn('bash', [SCRIPT_PATH], { stdio: 'inherit', cwd })
    proc.on('close', (code) => {
      if (code === 0) {
        resolve()
      } else {
        reject(new Error(`${SCRIPT_PATH} exited with code ${code}`))
      }
    })
    proc.on('error', reject)
  })
}

async function buildAndDeploy(key: string, cwd: string): Promise<void> {
  log(`[${key}] Build started`)
  try {
    await run(cwd)
    log(`[${key}] Deploy complete`)
  } catch (err) {
    log(`[${key}] Error: ${err instanceof Error ? err.message : String(err)}`)
  }
}

function schedule(key: string, cwd: string): void {
  const existing = timers.get(key)
  if (existing !== undefined) {
    clearTimeout(existing)
  }
  const t = setTimeout(() => {
    timers.delete(key)
    void buildAndDeploy(key, cwd)
  }, DEBOUNCE_MS)
  timers.set(key, t)
  log(`[${key}] Build scheduled in ${DEBOUNCE_MS}ms`)
}

function resolveKey(url: string | undefined): string | null {
  if (url === undefined) return null
  const segment = url.split('?')[0]?.split('/').filter(Boolean)[0]
  if (segment === undefined || !KEY_REGEX.test(segment)) return null
  return segment
}

const server = createServer((req: IncomingMessage, res: ServerResponse) => {
  if (req.method !== 'POST') {
    res.writeHead(405).end()
    return
  }
  if (SECRET !== null && req.headers['x-webhook-secret'] !== SECRET) {
    res.writeHead(401).end()
    return
  }

  const key = resolveKey(req.url)
  if (key === null) {
    res.writeHead(400).end('Invalid project key\n')
    return
  }

  const cwd = join(PROJECTS_ROOT, key)
  try {
    if (!statSync(cwd).isDirectory()) {
      res.writeHead(404).end(`${cwd} is not a directory\n`)
      return
    }
    if (!statSync(join(cwd, SCRIPT_PATH)).isFile()) {
      res.writeHead(404).end(`${SCRIPT_PATH} missing in ${cwd}\n`)
      return
    }
  } catch {
    res.writeHead(404).end(`${cwd} not found or ${SCRIPT_PATH} missing\n`)
    return
  }

  schedule(key, cwd)
  res.writeHead(202).end()
})

server.listen(PORT, HOST, () => {
  log(`Webhook receiver listening on ${HOST}:${PORT}`)
})
