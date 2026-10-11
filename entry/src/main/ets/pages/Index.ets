import { Course, Task, UserSettings, defaultUserSettings, sampleCourses, sampleTasks } from '../model/Types'
import { Dark } from '../common/Theme'
import { StudioHomePage } from './StudioHomePage'
import { SchedulePage } from './SchedulePage'
import { TodoPage } from './TodoPage'
import { TodoEditPage } from './TodoEditPage'
import { CourseEditPage } from './CourseEditPage'
import { CourseImportPage } from './CourseImportPage'
import { MinePage } from './MinePage'
import { SplashPage } from './SplashPage'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { notificationManager } from '@kit.NotificationKit'
import { promptAction } from '@kit.ArkUI'
import { SnapshotStore } from '../services/SnapshotStore'
import { CampusSnapshot, validateSnapshot, courseError, taskError, conflictWith, validLocalDateTime } from '../services/CampusRules'
import { SystemReminders, ReminderResult } from '../services/SystemReminders'
import { common } from '@kit.AbilityKit'

@Entry
@Component
struct Index {
  @State currentTab: number = 0
  private tabs: string[] = ['今日', '课表', '待办', '设置']
  private snapshotStore: SnapshotStore = new SnapshotStore()
  private mutationBusy: boolean = false
  private storageReady: boolean = false

  // 个性化设置
  @State settings: UserSettings = JSON.parse(JSON.stringify(defaultUserSettings)) as UserSettings

  // 全局课程 / 待办列表状态
  @State courses: Course[] = [...sampleCourses]
  @State tasks: Task[] = [...sampleTasks]

  // 课程编辑 / 导入状态
  @State editingCourse?: Course = undefined
  @State isEditingCourse: boolean = false
  @State isImportingCourse: boolean = false

  // 待办编辑状态（用 undefined 表示“没有任务”）
  @State editingTask?: Task = undefined
  @State isEditingTodo: boolean = false

  private reminderTimerId: number = -1
  @State private showSplash: boolean = false

  // 页面出现时，从本地加载数据
  aboutToAppear(): void {
    this.loadFromStorage().then(() => { if (this.storageReady) this.restoreReminderSchedules() })
    this.startReminderTicker()
  }

  aboutToDisappear(): void {
    this.stopReminderTicker()
  }

  private startReminderTicker() {
    if (this.reminderTimerId >= 0) {
      return
    }
    // 每 30 秒扫一次到点提醒（应用内可靠提醒，兼容当前 SDK/约束）
    this.reminderTimerId = setInterval(() => {
      this.checkAndFireDueReminders()
    }, 30 * 1000)
  }

  private stopReminderTicker() {
    if (this.reminderTimerId >= 0) {
      clearInterval(this.reminderTimerId)
      this.reminderTimerId = -1
    }
  }

  private async loadFromStorage() {
    try {
      const pref = await preferences.getPreferences(getContext(this), 'campusMate')
      const snapshot = await this.snapshotStore.load(getContext(this))
      if (snapshot) {
        this.courses = snapshot.courses
        this.tasks = snapshot.tasks
        this.settings = snapshot.settings
        this.storageReady = true
        return
      }
      const coursesStr = await pref.get('courses', '')
      const tasksStr = await pref.get('tasks', '')
      const settingsStr = await pref.get('settings', '')
      const legacy: CampusSnapshot = {
        version: 2, revision: 0, savedAt: Date.now(),
        courses: typeof coursesStr === 'string' && coursesStr ? JSON.parse(coursesStr) as Course[] : this.courses,
        tasks: typeof tasksStr === 'string' && tasksStr ? JSON.parse(tasksStr) as Task[] : this.tasks,
        settings: typeof settingsStr === 'string' && settingsStr ? JSON.parse(settingsStr) as UserSettings : this.settings
      }
      const error = validateSnapshot(legacy)
      if (error) throw new Error(error)
      this.courses = legacy.courses
      this.tasks = legacy.tasks
      this.settings = legacy.settings
      this.storageReady = await this.saveToStorage()
    } catch (err) {
      const e = err as BusinessError
      console.error(`loadFromStorage error: ${e.code}, ${e.message}`)
      promptAction.showToast({ message: '本地数据读取失败，暂未开放保存。请重启应用或恢复存储权限', duration: 3000 })
    }
  }

  private async commitData(courses: Course[], tasks: Task[], settings: UserSettings): Promise<boolean> {
    if (!this.storageReady) {
      promptAction.showToast({ message: '数据尚未完成读取，暂未保存，请稍后重试', duration: 2000 })
      return false
    }
    if (this.mutationBusy) {
      promptAction.showToast({ message: '正在保存，请稍后重试', duration: 2000 })
      return false
    }
    this.mutationBusy = true
    try {
      return await this.persistData(courses, tasks, settings)
    } finally {
      this.mutationBusy = false
    }
  }

  private async persistData(courses: Course[], tasks: Task[], settings: UserSettings): Promise<boolean> {
    try {
      const draft: CampusSnapshot = { version: 2, revision: 0, savedAt: Date.now(), courses: courses, tasks: tasks, settings: settings }
      const captured = JSON.parse(JSON.stringify(draft)) as CampusSnapshot
      await this.snapshotStore.save(getContext(this), captured)
      this.courses = captured.courses
      this.tasks = captured.tasks
      this.settings = captured.settings
      return true
    } catch (_) {
      promptAction.showToast({ message: '保存失败，本次数据未提交，请重试或导出备份', duration: 3000 })
      return false
    }
  }

  private async restoreReminderSchedules(): Promise<boolean> {
    if (this.mutationBusy) return false
    this.mutationBusy = true
    try { return await this.restoreSchedulesWithinMutation() }
    finally { this.mutationBusy = false }
  }

  private async restoreSchedulesWithinMutation(): Promise<boolean> {
    const next = JSON.parse(JSON.stringify(this.tasks)) as Task[]
    const newlyScheduled: Task[] = []
    for (let i = 0; i < next.length; i++) {
      if (next[i].done || !next[i].remindEnabled) continue
      const oldIds: number[] = [...(next[i].notificationIds ?? [])]
      const result = await SystemReminders.schedule(next[i])
      next[i].notificationIds = result.ids
      if (result.ids.some((id: number) => !oldIds.includes(id))) newlyScheduled.push(next[i])
    }
    if (await this.persistData(this.courses, next, this.settings)) return true
    for (let i = 0; i < newlyScheduled.length; i++) await SystemReminders.cancel(newlyScheduled[i])
    return false
  }

  private async updateTask(task: Task, remove: boolean = false): Promise<boolean> {
    if (!this.storageReady) return false
    if (this.mutationBusy) {
      promptAction.showToast({ message: '正在保存，请稍后重试', duration: 2000 })
      return false
    }
    this.mutationBusy = true
    try {
      const next = JSON.parse(JSON.stringify(this.tasks)) as Task[]
      const idx = next.findIndex((item: Task) => item.id === task.id)
      if (idx >= 0 && !(await SystemReminders.cancel(next[idx]))) {
        // Retain failed IDs for retry, without committing the requested edit.
        await this.persistData(this.courses, next, this.settings)
        promptAction.showToast({ message: '旧提醒取消失败，本次待办操作未提交，请重试', duration: 3000 })
        return false
      }
      const replacement = JSON.parse(JSON.stringify(task)) as Task
      replacement.notificationIds = []
      if (remove) {
        if (idx < 0) return false
        next.splice(idx, 1)
      } else if (idx >= 0) {
        next[idx] = replacement
      } else {
        next.push(replacement)
      }
      if (!(await this.persistData(this.courses, next, this.settings))) {
        if (idx >= 0) {
          const old = JSON.parse(JSON.stringify(this.tasks[idx])) as Task
          old.notificationIds = []
          const result = await SystemReminders.schedule(old)
          old.notificationIds = result.ids
          const restored: Task[] = [...this.tasks]
          restored[idx] = old
          if (!(await this.persistData(this.courses, restored, this.settings))) await SystemReminders.cancel(old)
        }
        return false
      }
      if (!remove && replacement.remindEnabled && !replacement.done) {
        const result = await this.scheduleTaskReminder(replacement)
        replacement.notificationIds = result.ids
        const scheduled: Task[] = [...this.tasks]
        const savedIdx = scheduled.findIndex((item: Task) => item.id === replacement.id)
        scheduled[savedIdx] = replacement
        if (!(await this.persistData(this.courses, scheduled, this.settings))) {
          await SystemReminders.cancel(replacement)
          promptAction.showToast({ message: '待办已保存，系统提醒未完成保存，请重试提醒设置', duration: 3000 })
        } else promptAction.showToast({ message: result.message, duration: 3000 })
      }
      return true
    } finally { this.mutationBusy = false }
  }

  private async replaceAllData(courses: Course[], tasks: Task[], settings: UserSettings): Promise<boolean> {
    if (!this.storageReady) return false
    if (this.mutationBusy) return false
    this.mutationBusy = true
    try {
      const previous = JSON.parse(JSON.stringify(this.tasks)) as Task[]
      let canceled = true
      for (let i = 0; i < previous.length; i++) {
        if (!(await SystemReminders.cancel(previous[i]))) canceled = false
      }
      if (!canceled) {
        await this.persistData(this.courses, previous, this.settings)
        await this.restoreSchedulesWithinMutation()
        promptAction.showToast({ message: '部分旧提醒取消失败，原课程与待办未替换，请重试', duration: 3000 })
        return false
      }
      const imported = JSON.parse(JSON.stringify(tasks)) as Task[]
      imported.forEach((item: Task) => {
        item.notificationIds = []
        if (item.remindEnabled === undefined) item.remindEnabled = !!item.remindAt
      })
      if (!(await this.persistData(courses, imported, settings))) {
        await this.restoreSchedulesWithinMutation()
        return false
      }
      await this.restoreSchedulesWithinMutation()
      return true
    } finally { this.mutationBusy = false }
  }

  private async scheduleTaskReminder(task: Task): Promise<ReminderResult> {
    if (task.remindEnabled && !task.done) {
      try {
        if (!(await notificationManager.isNotificationEnabled())) {
          await notificationManager.requestEnableNotification(getContext(this) as common.UIAbilityContext)
        }
      } catch (_) { /* service reports the actually available reminder channel */ }
    }
    return SystemReminders.schedule(task)
  }


  private getWeekNumber(): number {
    const start = this.settings.semesterStart
    if (!start || start.length < 10) {
      return 0
    }
    const parts = start.split('-')
    if (parts.length < 3) {
      return 0
    }
    const y = Number.parseInt(parts[0])
    const m = Number.parseInt(parts[1]) - 1
    const d = Number.parseInt(parts[2])
    if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d)) {
      return 0
    }
    const today = new Date()
    const diffMs = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()) - Date.UTC(y, m, d)
    if (diffMs < 0) {
      return 0
    }
    const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000))
    return Math.floor(diffDays / 7) + 1
  }

  private async saveToStorage(): Promise<boolean> {
    try {
      const snapshot: CampusSnapshot = { version: 2, revision: 0, savedAt: Date.now(), courses: this.courses, tasks: this.tasks, settings: this.settings }
      await this.snapshotStore.save(getContext(this), snapshot)
      return true
    } catch (err) {
      const e = err as BusinessError
      console.error(`saveToStorage error: ${e.code}, ${e.message}`)
      promptAction.showToast({ message: '保存失败，请先导出备份后再关闭应用', duration: 2500 })
      return false
    }
  }

  // 发送一个简单的待办通知（演示用：保存后立即弹出）
  private async sendTaskNotification(task: Task) {
    try {
      // 检查并请求通知开关
      const enabled = await notificationManager.isNotificationEnabled()
      if (!enabled) {
        // 使用回调方式请求开启通知权限（避免上下文类型问题）
        await notificationManager.requestEnableNotification(getContext(this) as common.UIAbilityContext)
        if (!(await notificationManager.isNotificationEnabled())) return
      }

      const request: notificationManager.NotificationRequest = {
        id: task.id,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: task.title,
            text: `${task.type} ｜ 截止：${task.deadline}`
          }
        }
      }
      await notificationManager.publish(request)
    } catch (err) {
      console.error(`sendTaskNotification error: ${JSON.stringify(err)}`)
    }
  }

  // ---------- 提醒系统（跨平台兼容）：NotificationKit 定时通知 ----------
  private parseRemindAtToDate(remindAt: string): Date | null {
    // 期望格式：'YYYY-MM-DD HH:mm'
    if (!remindAt) {
      return null
    }
    if (!validLocalDateTime(remindAt)) return null
    const parts = remindAt.trim().replace('T', ' ').split(' ')
    if (parts.length < 2) {
      return null
    }
    const ymd = parts[0].split('-')
    const hm = parts[1].split(':')
    if (ymd.length < 3 || hm.length < 2) {
      return null
    }
    const y = Number.parseInt(ymd[0])
    const m = Number.parseInt(ymd[1]) - 1
    const d = Number.parseInt(ymd[2])
    const hh = Number.parseInt(hm[0])
    const mm = Number.parseInt(hm[1])
    if ([y, m, d, hh, mm].some((n: number) => Number.isNaN(n))) {
      return null
    }
    return new Date(y, m, d, hh, mm, 0)
  }

  private async checkAndFireDueReminders(): Promise<void> {
    if (!this.storageReady || this.mutationBusy) return
    this.mutationBusy = true
    try {
    const now = Date.now()
    let changed = false
    const next = JSON.parse(JSON.stringify(this.tasks)) as Task[]
    const due: Task[] = []
    for (let i = 0; i < next.length; i++) {
      const t = next[i]
      if (t.done || (t.notificationIds ?? []).length > 0) {
        continue
      }
      if (!t.remindEnabled || !t.remindAt) {
        continue
      }
      const dt = this.parseRemindAtToDate(t.remindAt)
      if (dt == null) {
        continue
      }
      const advance = t.remindAdvanceMinutes ?? 0
      const fireAt = dt.getTime() - advance * 60 * 1000
      const last = t.lastRemindedAt ?? 0
      // 允许 2 分钟窗口，避免定时器漂移
      if (now >= fireAt && now - fireAt <= 2 * 60 * 1000 && last < fireAt) {
        due.push(JSON.parse(JSON.stringify(t)) as Task)
        next[i].lastRemindedAt = now
        changed = true

        // 简单重复：到点后把 remindAt 往后推
        const rep = t.remindRepeat ?? 'none'
        if (rep === 'daily') {
          dt.setDate(dt.getDate() + 1)
          next[i].remindAt = this.formatDateTime(dt)
        } else if (rep === 'weekly') {
          dt.setDate(dt.getDate() + 7)
          next[i].remindAt = this.formatDateTime(dt)
        } else {
          // 一次性提醒：触发后关闭
          next[i].remindEnabled = false
        }
      } else if (now > fireAt + 2 * 60 * 1000 && (t.remindRepeat === 'daily' || t.remindRepeat === 'weekly')) {
        const days = t.remindRepeat === 'weekly' ? 7 : 1
        do { dt.setDate(dt.getDate() + days) } while (dt.getTime() - advance * 60000 <= now)
        next[i].remindAt = this.formatDateTime(dt)
        changed = true
      }
    }
    if (changed && await this.persistData(this.courses, next, this.settings)) {
      for (let i = 0; i < due.length; i++) await this.sendTaskNotification(due[i])
    }
    } finally { this.mutationBusy = false }
  }

  private formatDateTime(d: Date): string {
    const y = d.getFullYear()
    const m = (d.getMonth() + 1).toString().padStart(2, '0')
    const day = d.getDate().toString().padStart(2, '0')
    const hh = d.getHours().toString().padStart(2, '0')
    const mm = d.getMinutes().toString().padStart(2, '0')
    return `${y}-${m}-${day} ${hh}:${mm}`
  }


  build() {
    Stack() {
      // 主界面
      Column() {
      // 顶部应用栏
      Column() {
        Text('CampusMate')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.settings.theme === 'dark' ? Dark.textPrimary : '#24262B')
          .margin({ top: 18, bottom: 4 })
        Text('让校园生活轻一点')
          .fontSize(13)
          .fontColor(this.settings.theme === 'dark' ? Dark.textSecondary : '#858992')

        // 顶部小标签行：Hi，昵称 · 第X周 或 今日日期
        Row() {
          Text(this.getTodayLabel())
            .fontSize(11)
            .fontColor('#5475A8')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.settings.theme === 'dark' ? Dark.accentBg : '#EEF2F8')
            .borderRadius(50)
          Blank()
        }
        .margin({ top: 10 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 14 })
      .backgroundColor(this.settings.theme === 'dark' ? Dark.bgHeader : '#FFFFFF')
      .borderRadius({ bottomLeft: 16, bottomRight: 16 })

      // 主体内容
      Stack() {
        if (this.currentTab === 0) {
          StudioHomePage({
            courses: this.courses,
            tasks: this.tasks,
            nickname: this.settings.nickname,
            weekNumber: this.getWeekNumber(),
            isDark: this.settings.theme === 'dark',
            onAddTodo: () => {
              this.currentTab = 2
              this.editingTask = undefined
              this.isEditingTodo = true
            }
          })
        } else if (this.currentTab === 1) {
          // 课表 Tab：课表列表 / 导入课程 / 编辑课程 三态
          if (this.isImportingCourse) {
            CourseImportPage({
              onConfirm: async (newCourses: Course[]) => {
                const combined: Course[] = [...this.courses]
                for (let i = 0; i < newCourses.length; i++) {
                  if (combined.some((c: Course) => c.id === newCourses[i].id)) {
                    promptAction.showToast({ message: `第${i + 1}行：课程ID重复，原数据未变更`, duration: 2500 })
                    return
                  }
                  const error = courseError(newCourses[i]) || conflictWith(newCourses[i], combined)
                  if (error) {
                    promptAction.showToast({ message: `第${i + 1}行：${error}`, duration: 2500 })
                    return
                  }
                  combined.push(newCourses[i])
                }
                if (await this.commitData(combined, this.tasks, this.settings)) {
                  this.isImportingCourse = false
                  promptAction.showToast({ message: `已导入 ${newCourses.length} 门课程`, duration: 2000 })
                }
              },
              onCancel: () => {
                this.isImportingCourse = false
              }
            })
          } else if (!this.isEditingCourse) {
            SchedulePage({
              courses: this.courses,
              weekNumber: this.getWeekNumber(),
              isDark: this.settings.theme === 'dark',
              onAddCourse: () => {
                this.editingCourse = undefined
                this.isEditingCourse = true
              },
              onEditCourse: (c: Course) => {
                this.editingCourse = c
                this.isEditingCourse = true
              },
              onImportCourse: () => {
                this.isImportingCourse = true
              }
            })
          } else {
            CourseEditPage({
              course: this.editingCourse ?? null,
              onCancel: () => {
                this.isEditingCourse = false
              },
              onSave: async (c: Course) => {
                const error = courseError(c) || conflictWith(c, this.courses)
                if (error) {
                  promptAction.showToast({ message: error, duration: 2500 })
                  return
                }
                const idx = this.courses.findIndex((item: Course) => item.id === c.id)
                const next: Course[] = [...this.courses]
                if (idx >= 0) {
                  next[idx] = c
                } else {
                  next.push(c)
                }
                if (await this.commitData(next, this.tasks, this.settings)) this.isEditingCourse = false
              },
              onDelete: async (c: Course) => {
                const next = this.courses.filter((item: Course) => item.id !== c.id)
                if (await this.commitData(next, this.tasks, this.settings)) this.isEditingCourse = false
              }
            })
          }
        } else if (this.currentTab === 3) {
          MinePage({
            settings: $settings,
            courses: this.courses,
            tasks: this.tasks,
            onSave: async (settings: UserSettings): Promise<boolean> => {
              return this.commitData(this.courses, this.tasks, settings)
            },
            onImportData: async (jsonStr: string): Promise<boolean> => {
              try {
                const obj = JSON.parse(jsonStr) as Record<string, Object>
                if (!obj || !Array.isArray(obj['courses']) || !Array.isArray(obj['tasks'])) {
                  promptAction.showToast({ message: '备份缺少courses/tasks；原数据未变更', duration: 2500 })
                  return false
                }
                const courses = (obj['courses'] as Course[]) ?? []
                const tasks = (obj['tasks'] as Task[]) ?? []
                const imported: CampusSnapshot = { version: 2, revision: 0, savedAt: Date.now(), courses: courses, tasks: tasks, settings: this.settings }
                if (obj['version'] !== undefined) imported.version = obj['version'] as number
                if (obj['settings']) imported.settings = obj['settings'] as UserSettings
                const error = validateSnapshot(imported)
                if (error) {
                  promptAction.showToast({ message: error + '；原数据未变更', duration: 2500 })
                  return false
                }
                return this.replaceAllData(courses, tasks, imported.settings)
              } catch (e) {
                console.error('import data error', e)
                promptAction.showToast({ message: '导入格式无效；原数据未变更', duration: 2500 })
                return false
              }
            },
            onClearData: async (): Promise<boolean> => {
              return this.replaceAllData([], [], this.settings)
            }
          })
        } else {
          // 待办 Tab 下，在列表和编辑页之间切换
          if (!this.isEditingTodo) {
            TodoPage({
              tasks: this.tasks,
              showCompleted: this.settings.taskListShowCompleted ?? true,
              isDark: this.settings.theme === 'dark',
              onAdd: () => {
                this.editingTask = undefined
                this.isEditingTodo = true
              },
              onEdit: (task: Task) => {
                this.editingTask = task
                this.isEditingTodo = true
              },
              onTaskToggle: async (task: Task, newDone: boolean) => {
                const next = JSON.parse(JSON.stringify(task)) as Task
                next.done = newDone
                if (newDone) next.remindEnabled = false
                if (await this.updateTask(next)) promptAction.showToast({ message: newDone ? `已完成：${task.title}` : '已恢复待办', duration: 2000 })
              }
            })
          } else {
            TodoEditPage({
              task: this.editingTask ?? null,
              defaultTodoType: this.settings.defaultTodoType ?? '作业',
              defaultRemindAdvanceMinutes: this.settings.defaultRemindAdvanceMinutes ?? 10,
              onCancel: () => {
                this.isEditingTodo = false
              },
              onSave: async (t: Task) => {
                const error = taskError(t)
                if (error) {
                  promptAction.showToast({ message: error, duration: 2500 })
                  return
                }
                if (await this.updateTask(t)) {
                  this.isEditingTodo = false
                  await this.checkAndFireDueReminders()
                }
              },
              onDelete: async (t: Task) => {
                if (await this.updateTask(t, true)) this.isEditingTodo = false
              }
            })
          }
        }
      }
      .layoutWeight(1)
      .backgroundColor(this.settings.theme === 'dark' ? Dark.bgContent : '#F6F7F9')

      // 底部导航栏
      Column() {
        Row() {
          ForEach(this.tabs, (item: string, index: number) => {
            Column() {
              if (this.currentTab === index) {
                // 选中态：圆角 pill
                Row() {
                  Text(item)
                    .fontSize(14)
                    .fontColor(this.settings.theme === 'dark' ? '#A9BEDA' : '#5475A8')
                    .fontWeight(FontWeight.Medium)
                }
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(this.settings.theme === 'dark' ? Dark.accentBg : '#EEF2F8')
                .borderRadius(20)
              } else {
                Text(item)
                  .fontSize(14)
                  .fontColor(this.settings.theme === 'dark' ? Dark.textSecondary : '#858992')
              }
            }
            .height(40)
            .width('25%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.currentTab = index
            })
          })
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(this.settings.theme === 'dark' ? Dark.bgTabBar : '#FFFFFF')
        .borderRadius({ topLeft: 16, topRight: 16 })
        .shadow({
          radius: this.settings.theme === 'dark' ? 8 : 12,
          color: this.settings.theme === 'dark' ? Dark.cardShadow : '#24262B1A',
          offsetX: 0,
          offsetY: -2
        })
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor(this.settings.theme === 'dark' ? Dark.bgRoot : '#F6F7F9')
    .visibility(this.showSplash ? Visibility.Hidden : Visibility.Visible)

      // 开屏动画（覆盖在最上层，动画结束后隐藏）
      if (this.showSplash) {
        SplashPage({
          onFinish: () => {
            this.showSplash = false
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  private getTodayLabel(): string {
    const weekNum = this.getWeekNumber()
    const nick = this.settings.nickname.trim()
    if (nick || weekNum > 0) {
      const parts: string[] = []
      if (nick) {
        parts.push(`Hi，${nick}`)
      }
      if (weekNum > 0) {
        parts.push(`第 ${weekNum} 周`)
      }
      return parts.join(' · ')
    }
    const now = new Date()
    const weekdayNames: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    const w = weekdayNames[now.getDay()]
    const m = now.getMonth() + 1
    const d = now.getDate()
    return `${m}月${d}日 · ${w}`
  }
}
