import { useEffect, useRef } from 'react'

type Particle = {
  startX: number
  startY: number
  vx: number
  vy: number
  rotation: number
  rotationSpeed: number
  colorIndex: number
  delay: number
  w: number
  h: number
}

const DURATION_S = 4.5
const FADE_START_S = 2.8
const GRAVITY = 700

function rand(min: number, max: number) {
  return min + Math.random() * (max - min)
}

function burst(count: number, width: number, height: number): Particle[] {
  const particles: Particle[] = []
  for (let i = 0; i < count; i++) {
    const fromBottom = i < count / 2
    particles.push({
      startX: rand(0, width),
      startY: fromBottom ? height : 0,
      vx: rand(-190, 190),
      vy: fromBottom ? rand(-1050, -450) : rand(280, 750),
      rotation: rand(0, 360),
      rotationSpeed: rand(-420, 420),
      colorIndex: Math.floor(Math.random() * 2),
      delay: rand(0, 0.35),
      w: rand(7, 17),
      h: rand(4, 10),
    })
  }
  return particles
}

/**
 * Mirrors ConfettiView.swift's physics-based burst -- half the particles
 * launch upward from the bottom, half fall from the top, all under
 * gravity, fading out between 2.8s and 4.5s. MatchDetail fires this once
 * when a Final's result loads with a winner.
 */
export default function ConfettiOverlay({ colors }: { colors: [string, string] }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    const ctx = canvas?.getContext('2d')
    if (!canvas || !ctx) return

    const dpr = window.devicePixelRatio || 1
    const width = window.innerWidth
    const height = window.innerHeight
    canvas.width = width * dpr
    canvas.height = height * dpr
    ctx.scale(dpr, dpr)

    const particles = burst(200, width, height)
    const startTime = performance.now()
    let frameId: number

    function frame(now: number) {
      const elapsed = (now - startTime) / 1000
      ctx!.clearRect(0, 0, width, height)

      for (const p of particles) {
        const t = elapsed - p.delay
        if (t <= 0 || t >= DURATION_S) continue

        const x = p.startX + p.vx * t
        const y = p.startY + p.vy * t + 0.5 * GRAVITY * t * t
        const angleRad = ((p.rotation + p.rotationSpeed * t) * Math.PI) / 180
        const opacity = Math.max(0, Math.min(1, 1 - (t - FADE_START_S) / (DURATION_S - FADE_START_S)))

        ctx!.save()
        ctx!.globalAlpha = opacity
        ctx!.translate(x, y)
        ctx!.rotate(angleRad)
        ctx!.fillStyle = colors[p.colorIndex % colors.length]
        ctx!.fillRect(-p.w / 2, -p.h / 2, p.w, p.h)
        ctx!.restore()
      }

      if (elapsed < DURATION_S + 0.5) frameId = requestAnimationFrame(frame)
    }
    frameId = requestAnimationFrame(frame)

    return () => cancelAnimationFrame(frameId)
  }, [colors])

  return <canvas ref={canvasRef} className="confetti-overlay" aria-hidden="true" />
}
