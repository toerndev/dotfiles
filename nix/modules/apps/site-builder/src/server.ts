import { spawn } from 'node:child_process'
import { statSync } from 'node:fs'
import { createServer } from 'node:http'
import type { IncomingMessage, ServerResponse } from 'node:http'
import { join } from 'node:path'

const HOST = process.env['WEBHOOK_HOST'] ?? '127.0.0.1'
const PORT = Number(process.env['WEBHOOK_PORT'] ?? '9055')
const SECRET = process.env['WEBHOOK_SECRET'] ?? null

const ROOT = '/srv'
const KEY_RE = /^[a-zA-Z0-9_-]+$/

// Per-project state. Absent = idle.
type Job = { phase: 'build' | 'deploy'; pending: boolean; ac: AbortController }
const jobs = new Map<string, Job>()

const log = (msg: string) => console.log(`[${new Date().toISOString()}] ${msg}`)

function sh(script: string, cwd: string, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const p = spawn('bash', [script], { stdio: 'inherit', cwd, signal })
    const aborted = () => reject(Object.assign(new Error('aborted'), { name: 'AbortError' }))
    p.on('close', (code) => (signal?.aborted ? aborted() : code === 0 ? resolve() : reject(new Error(`${script} exited with code ${code}`))))
    p.on('error', (e) => (signal?.aborted ? aborted() : reject(e)))
  })
}

function isFile(p: string) {
  try { return statSync(p).isFile() } catch { return false }
}

function hasSplit(cwd: string) {
  return isFile(join(cwd, 'scripts/build.sh')) && isFile(join(cwd, 'scripts/deploy.sh'))
}

// Builds immediately; if a signal arrives during the build phase the build is
// aborted and restarted. Signals during deploy queue one rebuild. deploy.sh is
// never interrupted, so dist/ is always complete when wrangler reads it.
async function buildLoop(key: string, cwd: string): Promise<void> {
  const split = hasSplit(cwd)

  while (true) {
    const ac = new AbortController()
    jobs.set(key, { phase: 'build', pending: false, ac })
    log(`[${key}] Build started`)

    try {
      await sh(split ? 'scripts/build.sh' : 'scripts/build-and-deploy.sh', cwd, split ? ac.signal : undefined)
    } catch (e) {
      if (e instanceof Error && e.name === 'AbortError') {
        log(`[${key}] Build aborted — restarting`)
        continue
      }
      log(`[${key}] Error: ${e instanceof Error ? e.message : e}`)
      break
    }

    // After build: if a signal arrived and we have split scripts, skip deploy
    // and restart build now (no point deploying a build that's already stale).
    if (split && jobs.get(key)!.pending) {
      log(`[${key}] Running queued build`)
      continue
    }

    if (split) {
      jobs.set(key, { phase: 'deploy', pending: false, ac: new AbortController() })
      try {
        await sh('scripts/deploy.sh', cwd)
      } catch (e) {
        log(`[${key}] Deploy error: ${e instanceof Error ? e.message : e}`)
        break
      }
    }

    log(`[${key}] Deploy complete`)
    if (!jobs.get(key)!.pending) break
    log(`[${key}] Running queued build`)
  }

  jobs.delete(key)
}

function trigger(key: string, cwd: string): void {
  const job = jobs.get(key)
  if (job === undefined) {
    void buildLoop(key, cwd)
  } else if (job.phase === 'build') {
    log(`[${key}] Signal during build — aborting and restarting`)
    job.ac.abort()
  } else if (!job.pending) {
    log(`[${key}] Signal during deploy — queuing rebuild`)
    job.pending = true
  }
}

function resolveKey(url: string | undefined): string | null {
  const seg = url?.split('?')[0]?.split('/').filter(Boolean)[0]
  return seg !== undefined && KEY_RE.test(seg) ? seg : null
}

function checkProject(cwd: string): string | null {
  try {
    if (!statSync(cwd).isDirectory()) return `${cwd} is not a directory`
    if (!hasSplit(cwd) && !isFile(join(cwd, 'scripts/build-and-deploy.sh'))) return `no build script in ${cwd}`
    return null
  } catch {
    return `${cwd} not found`
  }
}

const server = createServer((req: IncomingMessage, res: ServerResponse) => {
  if (req.method !== 'POST') { res.writeHead(405).end(); return }
  if (SECRET !== null && req.headers['x-webhook-secret'] !== SECRET) { res.writeHead(401).end(); return }

  const key = resolveKey(req.url)
  if (key === null) { res.writeHead(400).end('Invalid project key\n'); return }

  const cwd = join(ROOT, key)
  const err = checkProject(cwd)
  if (err !== null) { res.writeHead(404).end(`${err}\n`); return }

  trigger(key, cwd)
  res.writeHead(202).end()
})

server.listen(PORT, HOST, () => log(`Webhook receiver listening on ${HOST}:${PORT}`))
