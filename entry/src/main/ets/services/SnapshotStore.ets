import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { CampusSnapshot, validateSnapshot } from './CampusRules'

/** Independently implemented A/B commit protocol; never overwrite the active slot first. */
export class SnapshotStore {
  private revision: number = 0
  private currentSlot: string = ''
  private currentRaw: string = ''
  private needsPointerRepair: boolean = false
  private queue: Promise<void> = Promise.resolve()

  async load(context: common.Context): Promise<CampusSnapshot | undefined> {
    const pref = await preferences.getPreferences(context, 'campusMate')
    let pointer: string = ''
    try { pointer = await pref.get('snapshot_active', '') as string } catch (_) { this.needsPointerRepair = true }
    const active = pointer === 'b' ? 'b' : 'a'
    const names: string[] = [active, active === 'a' ? 'b' : 'a']
    let storedDataExists: boolean = false
    for (let i = 0; i < names.length; i++) {
      try {
        const raw = await pref.get('snapshot_' + names[i], '') as string
        if (!raw) continue
        storedDataExists = true
        const snapshot = JSON.parse(raw) as CampusSnapshot
        if (validateSnapshot(snapshot)) continue
        this.revision = Math.max(this.revision, snapshot.revision ?? 0)
        this.currentSlot = names[i]
        this.currentRaw = raw
        this.needsPointerRepair = false
        if (names[i] !== pointer) {
          // Repair the pointer so the next commit writes into the damaged slot.
          try { await pref.put('snapshot_active', names[i]); await pref.flush() } catch (_) { this.needsPointerRepair = true }
        }
        return snapshot
      } catch (_) { storedDataExists = true /* damaged slot: try the other retained revision */ }
    }
    if (storedDataExists) throw new Error('双快照均不可读，请保留原数据并恢复备份')
    return undefined
  }

  save(context: common.Context, snapshot: CampusSnapshot): Promise<void> {
    // Capture immutable data before queuing; a later UI edit cannot change an in-flight save.
    const captured = JSON.stringify(snapshot)
    const operation = this.queue.catch(() => {}).then(async () => {
      const value = JSON.parse(captured) as CampusSnapshot
      const error = validateSnapshot(value)
      if (error) throw new Error(error)
      const pref = await preferences.getPreferences(context, 'campusMate')
      let active = await pref.get('snapshot_active', '') as string
      if (this.currentSlot && await pref.get('snapshot_' + this.currentSlot, '') !== this.currentRaw) throw new Error('数据已在其他窗口变更，请重新加载')
      if (this.needsPointerRepair && this.currentSlot) {
        // Recovery may have loaded the fallback while pointer repair failed. Preserve it.
        await pref.put('snapshot_active', this.currentSlot)
        await pref.flush()
        active = this.currentSlot
        this.needsPointerRepair = false
      }
      if (this.currentSlot && active !== this.currentSlot) throw new Error('数据已在其他窗口变更，请重新加载')
      if (!this.currentSlot && (await pref.get('snapshot_a', '') || await pref.get('snapshot_b', ''))) throw new Error('存在未读取的快照，请重新加载')
      const target = this.currentSlot === 'a' ? 'b' : 'a'
      value.version = 2
      value.revision = ++this.revision
      value.savedAt = Date.now()
      const raw = JSON.stringify(value)
      await pref.put('snapshot_' + target, raw)
      await pref.flush()
      const check = await pref.get('snapshot_' + target, '') as string
      if (check !== raw) throw new Error('快照读回校验失败')
      try {
        await pref.put('snapshot_active', target)
        await pref.flush()
      } catch (error) {
        // Preferences has an in-memory cache. Restore its pointer too if flush fails.
        try { await pref.put('snapshot_active', this.currentSlot || active); await pref.flush() } catch (_) {}
        this.needsPointerRepair = !!this.currentSlot
        throw new Error((error as Error).message || '快照提交失败')
      }
      this.currentSlot = target
      this.currentRaw = raw
    })
    this.queue = operation
    return operation
  }
}
