/**
 * 深色模式统一色板，避免粗糙的纯灰
 */
export interface DarkThemeColors {
  bgRoot: string
  bgHeader: string
  bgContent: string
  bgCard: string
  bgTabBar: string
  border: string
  borderLight: string
  accentBg: string
  textPrimary: string
  textSecondary: string
  textMuted: string
  cardShadow: string
  surfaceElevated: string
}

export const Dark: DarkThemeColors = {
  bgRoot: '#0D0D10',
  bgHeader: '#16161D',
  bgContent: '#121218',
  bgCard: '#1E1E26',
  bgTabBar: '#1A1A22',
  border: '#2A2A36',
  borderLight: '#363646',
  accentBg: '#1E2D4A',
  textPrimary: '#F2F2F7',
  textSecondary: '#A8A8B8',
  textMuted: '#6E6E80',
  cardShadow: '#35000000',
  surfaceElevated: '#252530'
}
