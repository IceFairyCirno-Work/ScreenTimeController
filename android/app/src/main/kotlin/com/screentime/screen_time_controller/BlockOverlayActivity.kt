package com.screentime.screen_time_controller

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * Full-screen block UI shown when the user opens a blocked app.
 */
class BlockOverlayActivity : Activity() {
    companion object {
        private const val EXTRA_PACKAGE = "blocked_package"
        private const val SHOW_DEBOUNCE_MS = 200L

        @Volatile
        private var lastShownPackage: String? = null

        @Volatile
        private var lastShownTimeMs: Long = 0

        fun show(context: Context, packageName: String) {
            val now = System.currentTimeMillis()
            synchronized(this) {
                if (packageName == lastShownPackage &&
                    now - lastShownTimeMs < SHOW_DEBOUNCE_MS
                ) {
                    return
                }
                lastShownPackage = packageName
                lastShownTimeMs = now
            }

            val intent = Intent(context, BlockOverlayActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION,
                )
                putExtra(EXTRA_PACKAGE, packageName)
            }
            context.startActivity(intent)
        }

        private fun clearShowState() {
            synchronized(this) {
                lastShownPackage = null
                lastShownTimeMs = 0
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block_overlay)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        findViewById<Button>(R.id.btnClose).setOnClickListener {
            goHome()
        }

        applyRandomOverlayContent()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyRandomOverlayContent()
    }

    private fun applyRandomOverlayContent() {
        val quote = BlockOverlayContent.randomQuote()
        val backgroundColor = BlockOverlayContent.randomBackgroundColor()

        findViewById<LinearLayout>(R.id.overlayRoot).setBackgroundColor(backgroundColor)
        findViewById<TextView>(R.id.txtEmoji).text = quote.emoji
        findViewById<TextView>(R.id.txtQuote).text = "\"${quote.text}\""
        findViewById<TextView>(R.id.txtAuthor).text = "— ${quote.author}"
        findViewById<Button>(R.id.btnClose).setTextColor(backgroundColor)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        goHome()
    }

    private fun goHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    override fun onDestroy() {
        clearShowState()
        super.onDestroy()
    }
}
