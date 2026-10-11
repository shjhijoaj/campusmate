// 数据模型与示例数据

export interface Course {
  id: number
  name: string
  classroom: string
  weekday: number  // 1-7
  time: string
  startWeek?: number
  endWeek?: number
  weekMode?: 'all' | 'odd' | 'even'
  teacher?: string
  color?: string
}

export interface Task {
  id: number
  title: string
  courseName?: string
  type: string
  deadline: string
  done: boolean

  // 系统代理提醒成功后记录 id；失败时仅使用应用内通道并明确告知。
  remindEnabled?: boolean
  remindAt?: string              // 'YYYY-MM-DD HH:mm'
  remindAdvanceMinutes?: number  // 提前分钟：0/10/30/60...
  remindRepeat?: 'none' | 'daily' | 'weekly'
  notificationIds?: number[]     // NotificationKit 调度的通知 id 列表
  lastRemindedAt?: number        // 应用内提醒：上次提醒时间戳（ms）
}

export const sampleCourses: Course[] = [
  { id: 1, name: '高等数学', classroom: '教一-301', weekday: 1, time: '08:00 - 09:35' },
  { id: 2, name: '数据结构', classroom: '教二-204', weekday: 1, time: '10:00 - 11:35' },
  { id: 3, name: '操作系统', classroom: '实训楼-502', weekday: 2, time: '14:00 - 15:35' },
  { id: 4, name: '计算机网络', classroom: '教三-105', weekday: 3, time: '16:00 - 17:35' },
  { id: 5, name: '创新项目工作坊', classroom: '创新实验室-302', weekday: 6, time: '10:00 - 11:35', teacher: '项目组', color: '#F7EBDD' },
  { id: 6, name: '作品集设计讨论', classroom: '图书馆-研讨室', weekday: 6, time: '14:00 - 15:35', teacher: '项目组', color: '#E7EEE5' },
]

function sampleDeadline(daysLater: number, time: string): string {
  const date = new Date()
  date.setDate(date.getDate() + daysLater)
  return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')} ${time}`
}

export const sampleTasks: Task[] = [
  { id: 1, title: '高数作业第 5 章', courseName: '高等数学', type: '作业', deadline: sampleDeadline(0, '23:00'), done: false },
  { id: 2, title: '数据结构上机实验报告', courseName: '数据结构', type: '项目', deadline: sampleDeadline(1, '18:00'), done: false },
  { id: 3, title: '操作系统小测准备', courseName: '操作系统', type: '考试', deadline: sampleDeadline(2, '20:00'), done: true },
]

// 个性化与各项设置
export interface UserSettings {
  nickname: string
  semesterStart: string  // 格式 YYYY-MM-DD，如 2025-09-01
  theme?: 'light' | 'dark'
  weekStartsOnMonday?: boolean   // 周一为第一天
  defaultRemindAdvanceMinutes?: number  // 新建待办默认提前提醒分钟
  defaultTodoType?: string       // 新建待办默认类型
  taskListShowCompleted?: boolean  // 待办列表是否显示已完成
  hapticOn?: boolean            // 震动反馈
}

export const defaultUserSettings: UserSettings = {
  nickname: '宋浩',
  semesterStart: '2026-09-07',
  theme: 'light',
  weekStartsOnMonday: true,
  defaultRemindAdvanceMinutes: 10,
  defaultTodoType: '作业',
  taskListShowCompleted: true,
  hapticOn: true
}

/** 用于 MinePage 中合并设置（ArkTS 不允许对象展开） */
export interface SettingsPatch {
  nickname?: string
  semesterStart?: string
  theme?: 'light' | 'dark'
  weekStartsOnMonday?: boolean
  defaultRemindAdvanceMinutes?: number
  defaultTodoType?: string
  taskListShowCompleted?: boolean
  hapticOn?: boolean
}

/** 导出数据结构 */
export interface ExportData {
  version?: number
  courses: Course[]
  tasks: Task[]
  settings?: UserSettings
  exportTime: string
}

/** 弹窗按钮 */
export interface DialogButton {
  text: string
  color: string
}

/** 弹窗结果 */
export interface DialogResult {
  index: number
}

