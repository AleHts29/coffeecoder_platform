// Preferencias del player por dispositivo. No son datos sensibles ni
// tokens: localStorage está bien acá.
const KEY_AUTOPLAY = 'cc.player.autoplay'
const KEY_RATE = 'cc.player.rate'

function read(key: string): string | null {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}

function write(key: string, value: string) {
  try {
    localStorage.setItem(key, value)
  } catch {
    /* sin storage */
  }
}

export const prefs = {
  autoplay: () => read(KEY_AUTOPLAY) !== 'off',
  setAutoplay: (on: boolean) => write(KEY_AUTOPLAY, on ? 'on' : 'off'),
  rate: () => Number(read(KEY_RATE) ?? '1') || 1,
  setRate: (r: number) => write(KEY_RATE, String(r)),
}
