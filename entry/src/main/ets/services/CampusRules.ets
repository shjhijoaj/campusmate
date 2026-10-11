import { Course, Task, UserSettings } from '../model/Types'

export interface CampusSnapshot {
  version: number
  revision: number
  savedAt: number
  courses: Course[]
  tasks: Task[]
  settings: UserSettings
}

export function activeInWeek(c: Course, week: number): boolean {
  if (week < (c.startWeek ?? 1) || week > (c.endWeek ?? 20)) return false
  return c.weekMode === 'odd' ? week % 2 === 1 : c.weekMode === 'even' ? week % 2 === 0 : true
}

export function minutes(text: string): number {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(text.trim())) return -1
  const parts = text.trim().split(':')
  return Number(parts[0]) * 60 + Number(parts[1])
}

export function courseError(c: Course): string {
  if (!c || typeof c.name !== 'string' || !c.name.trim() || c.name.length > 80) return '课程名不能为空且不能超过80字'
  if (!Number.isSafeInteger(c.id) || c.id < 1) return '课程ID须为正整数'
  if (!Number.isInteger(c.weekday) || c.weekday < 1 || c.weekday > 7) return '星期须为1至7'
  if (typeof c.classroom !== 'string' || typeof c.time !== 'string') return '教室和时间必须为文本'
  if (c.classroom.length > 100) return '教室最多100字'
  if (c.teacher !== undefined && (typeof c.teacher !== 'string' || c.teacher.length > 50)) return '教师应为文本且最多50字'
  if (c.color !== undefined && (typeof c.color !== 'string' || !/^#[\da-f]{6}$/i.test(c.color))) return '课程颜色须为六位十六进制'
  const times = c.time.split('-')
  if (times.length !== 2 || minutes(times[0]) < 0 || minutes(times[1]) <= minutes(times[0])) return '时间格式应为08:00-09:35，结束须晚于开始'
  const start = c.startWeek ?? 1
  const end = c.endWeek ?? 20
  if (!Number.isInteger(start) || !Number.isInteger(end) || start < 1 || end > 30 || start > end) return '周次须为1至30且起始不晚于结束'
  if (c.weekMode !== undefined && c.weekMode !== 'all' && c.weekMode !== 'odd' && c.weekMode !== 'even') return '单双周仅支持all/odd/even'
  return ''
}

/** Accept both native space-separated dates and browser companion local ISO dates. */
export function validLocalDateTime(text: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}$/.test(text)) return false
  const normalized = text.replace(' ', 'T')
  const date = new Date(normalized)
  const parts = normalized.substring(0, 10).split('-')
  return !Number.isNaN(date.getTime()) && minutes(normalized.substring(11)) >= 0 &&
    date.getFullYear() === Number(parts[0]) && date.getMonth() + 1 === Number(parts[1]) && date.getDate() === Number(parts[2])
}

export function taskError(t: Task): string {
  if (!t || !Number.isSafeInteger(t.id) || t.id < 1) return '待办ID须为正整数'
  if (typeof t.title !== 'string' || !t.title.trim() || t.title.length > 160) return '待办标题不能为空且不能超过160字'
  if (typeof t.type !== 'string' || typeof t.deadline !== 'string' || typeof t.done !== 'boolean') return '待办类型、截止日期或完成状态无效'
  if (!['作业', '项目', '考试', '其他'].includes(t.type)) return '未知待办类型'
  // Original native tasks explicitly allow an unset deadline; malformed dates do not.
  if (t.deadline !== '' && t.deadline !== '未设置' && !validLocalDateTime(t.deadline)) return '截止时间格式无效'
  if (t.courseName !== undefined && (typeof t.courseName !== 'string' || t.courseName.length > 80)) return '关联课程应为文本且最多80字'
  if (t.remindEnabled !== undefined && typeof t.remindEnabled !== 'boolean') return '提醒开关格式无效'
  if (t.remindAt !== undefined && (typeof t.remindAt !== 'string' || (t.remindAt !== '' && !validLocalDateTime(t.remindAt)))) return '提醒时间格式无效'
  if (t.remindEnabled && !t.remindAt) return '开启提醒后须填写提醒时间'
  if (t.remindAdvanceMinutes !== undefined && (!Number.isInteger(t.remindAdvanceMinutes) || t.remindAdvanceMinutes < 0 || t.remindAdvanceMinutes > 10080)) return '提前提醒分钟须为0至10080'
  if (t.remindRepeat !== undefined && !['none', 'daily', 'weekly'].includes(t.remindRepeat)) return '重复提醒规则无效'
  if (t.notificationIds !== undefined) {
    if (!Array.isArray(t.notificationIds) || t.notificationIds.length > 64) return '系统提醒ID格式无效'
    for (let i = 0; i < t.notificationIds.length; i++) {
      if (!Number.isSafeInteger(t.notificationIds[i]) || t.notificationIds[i] < 0) return '系统提醒ID格式无效'
    }
  }
  if (t.lastRemindedAt !== undefined && (!Number.isFinite(t.lastRemindedAt) || t.lastRemindedAt < 0)) return '提醒记录格式无效'
  return ''
}

export function validateSnapshot(s: CampusSnapshot): string {
  if (!s || !Array.isArray(s.courses) || !Array.isArray(s.tasks) || !s.settings) return '文件缺少courses/tasks/settings'
  if (s.version !== undefined && s.version !== 2) return '不支持此数据版本'
  if (s.revision !== undefined && (!Number.isSafeInteger(s.revision) || s.revision < 0)) return '修订号格式无效'
  if (s.courses.length > 500 || s.tasks.length > 1000) return '超出数据数量上限'
  const ids: number[] = []
  for (let i = 0; i < s.courses.length; i++) {
    const error = courseError(s.courses[i])
    if (error) return `课程第${i + 1}行：${error}`
    if (ids.includes(s.courses[i].id)) return `课程第${i + 1}行：ID重复`
    const conflict = conflictWith(s.courses[i], s.courses.slice(0, i))
    if (conflict) return `课程第${i + 1}行：${conflict}`
    ids.push(s.courses[i].id)
  }
  const taskIds: number[] = []
  for (let i = 0; i < s.tasks.length; i++) {
    const error = taskError(s.tasks[i])
    if (error) return `待办第${i + 1}行：${error}`
    if (taskIds.includes(s.tasks[i].id)) return `待办第${i + 1}行：ID重复`
    taskIds.push(s.tasks[i].id)
  }
  if (typeof s.settings.nickname !== 'string' || typeof s.settings.semesterStart !== 'string') return '个人设置格式无效'
  if (s.settings.nickname.length > 40) return '昵称最多40字'
  if (s.settings.semesterStart && !/^\d{4}-\d{2}-\d{2}$/.test(s.settings.semesterStart)) return '开学日期应为YYYY-MM-DD'
  if (s.settings.semesterStart) {
    const date = new Date(s.settings.semesterStart + 'T12:00:00')
    const parts = s.settings.semesterStart.split('-')
    if (Number.isNaN(date.getTime()) || date.getFullYear() !== Number(parts[0]) || date.getMonth() + 1 !== Number(parts[1]) || date.getDate() !== Number(parts[2])) return '开学日期不存在'
  }
  if (s.settings.theme !== undefined && s.settings.theme !== 'light' && s.settings.theme !== 'dark') return '主题格式无效'
  if (s.settings.weekStartsOnMonday !== undefined && typeof s.settings.weekStartsOnMonday !== 'boolean') return '每周起始日格式无效'
  if (s.settings.taskListShowCompleted !== undefined && typeof s.settings.taskListShowCompleted !== 'boolean') return '完成任务显示设置无效'
  if (s.settings.hapticOn !== undefined && typeof s.settings.hapticOn !== 'boolean') return '触感设置无效'
  if (s.settings.defaultTodoType !== undefined && !['作业', '项目', '考试', '其他'].includes(s.settings.defaultTodoType)) return '默认待办类型无效'
  if (s.settings.defaultRemindAdvanceMinutes !== undefined && (!Number.isInteger(s.settings.defaultRemindAdvanceMinutes) || s.settings.defaultRemindAdvanceMinutes < 0 || s.settings.defaultRemindAdvanceMinutes > 10080)) return '默认提醒分钟须为0至10080'
  return ''
}

export function conflictWith(c: Course, list: Course[]): string {
  const range = c.time.split('-')
  if (range.length !== 2) return ''
  for (let i = 0; i < list.length; i++) {
    const other = list[i]
    if (other.id === c.id || other.weekday !== c.weekday) continue
    const times = other.time.split('-')
    if (times.length !== 2) continue
    if (minutes(range[0]) >= minutes(times[1]) || minutes(times[0]) >= minutes(range[1])) continue
    for (let week = 1; week <= 30; week++) {
      if (activeInWeek(c, week) && activeInWeek(other, week)) return `与「${other.name}」第${week}周时间冲突`
    }
  }
  return ''
}
