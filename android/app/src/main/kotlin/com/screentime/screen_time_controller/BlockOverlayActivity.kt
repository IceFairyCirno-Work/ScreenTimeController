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

        internal fun launch(context: Context, packageName: String) {
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

        val blockedPackage = intent.getStringExtra(EXTRA_PACKAGE).orEmpty()
        BlockOverlayCoordinator.prepareSession(blockedPackage)
        applyOverlayContent()
    }

    override fun onResume() {
        super.onResume()
        BlockOverlayCoordinator.onActivityResumed(intent.getStringExtra(EXTRA_PACKAGE))
    }

    override fun onPause() {
        BlockOverlayCoordinator.onActivityPaused()
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun applyOverlayContent() {
        val blockedPackage = intent.getStringExtra(EXTRA_PACKAGE).orEmpty()
        val (quote, backgroundColor) =
            BlockOverlayCoordinator.currentContent()
                ?: BlockOverlayCoordinator.prepareSession(blockedPackage)

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
        BlockOverlayCoordinator.onUserDismissed()
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }
}
