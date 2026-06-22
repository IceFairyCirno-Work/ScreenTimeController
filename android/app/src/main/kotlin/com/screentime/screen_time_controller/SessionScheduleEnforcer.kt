package com.screentime.screen_time_controller

import java.util.Calendar

/**
 * Evaluates schedule (session) rules on the native side so blocking can begin
 * exactly when a window opens, even if Flutter is backgrounded.
 */
object SessionScheduleEnforcer {
    fun shouldEnforce(
        packageName: String,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean {
        val until = TemporaryUnblocksStore.unblockUntil(packageName)
        if (until != null && until > nowMs) return false

        val ruleEntries = SessionScheduleRulesStore.entriesFor(packageName)
        if (ruleEntries.isEmpty()) return false

        val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
        for (entry in ruleEntries) {
            if (entry.isDisabled(nowMs)) continue
            if (isWithinWindow(entry, calendar)) return true
        }
        return false
    }

    private fun isWithinWindow(
        entry: SessionScheduleRulesStore.Entry,
        calendar: Calendar,
    ): Boolean {
        val repeatDay = calendarDayToRepeatDay(calendar.get(Calendar.DAY_OF_WEEK))
        if (repeatDay !in entry.repeatDays) return false

        val startMinutes = entry.startHour * 60 + entry.startMinute
        val endMinutes = entry.endHour * 60 + entry.endMinute
        val atMinutes =
            calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)

        return if (startMinutes <= endMinutes) {
            atMinutes >= startMinutes && atMinutes < endMinutes
        } else {
            // Overnight window — attributed to the start day.
            atMinutes >= startMinutes || atMinutes < endMinutes
        }
    }

    /** Maps [Calendar.DAY_OF_WEEK] to Dart [RepeatDay] index (Mon = 0 … Sun = 6). */
    private fun calendarDayToRepeatDay(dayOfWeek: Int): Int = (dayOfWeek + 5) % 7
}
