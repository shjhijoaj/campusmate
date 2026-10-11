import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { Task } from '../model/Types'

export interface ReminderResult { ids: number[]; message: string }

export class SystemReminders {
  static async cancel(task: Task): Promise<boolean> {
    const ids: number[] = task.notificationIds ?? []
    const failed: number[] = []
    for (let i = 0; i < ids.length; i++) {
      try { await reminderAgentManager.cancelReminder(ids[i]) } catch (_) { failed.push(ids[i]) }
    }
    task.notificationIds = failed
    return !failed.length
  }

  static async schedule(task: Task): Promise<ReminderResult> {
    if (!(await SystemReminders.cancel(task))) return { ids: task.notificationIds ?? [], message: '旧系统提醒取消失败，未重复排期，请在设备上重试' }
    if (!task.remindEnabled || task.done || !task.remindAt) return { ids: [], message: '提醒已关闭' }
    if (task.remindRepeat && task.remindRepeat !== 'none') return { ids: [], message: '重复提醒使用应用内通道（需保持应用运行）' }
    const date = new Date(task.remindAt.replace(' ', 'T'))
    const fireAt = date.getTime() - (task.remindAdvanceMinutes ?? 0) * 60000
    if (!Number.isFinite(fireAt) || fireAt <= Date.now()) return { ids: [], message: '提醒时间需晚于当前时间' }
    try {
      if (!(await notificationManager.isNotificationEnabled())) return { ids: [], message: '尚未允许通知，暂使用应用内提醒' }
      // Timer requests are available from early HarmonyOS APIs; no API 19/24-only calls.
      const request: reminderAgentManager.ReminderRequestTimer = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
        triggerTimeInSeconds: Math.max(1, Math.ceil((fireAt - Date.now()) / 1000)),
        title: task.title,
        content: `${task.type} · ${task.deadline}`,
        notificationId: task.id % 2147483647,
        ringDuration: 3,
        slotType: notificationManager.SlotType.SERVICE_INFORMATION
      }
      const id = await reminderAgentManager.publishReminder(request)
      return { ids: [id], message: '已提交系统代理提醒；请在目标设备验证后台触发' }
    } catch (_) {
      return { ids: [], message: '系统代理提醒不可用，暂使用应用内提醒（需保持应用运行）' }
    }
  }
}
