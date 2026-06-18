package com.screentime.screen_time_controller

import kotlin.random.Random

data class BlockQuote(
    val emoji: String,
    val text: String,
    val author: String,
)

object BlockOverlayContent {
    private val quotes = listOf(
        BlockQuote(
            emoji = "🍃",
            text = "You don't always need a plan. Sometimes you just need to breathe, trust, let go, and see what happens.",
            author = "Mandy Hale",
        ),
        BlockQuote(
            emoji = "⚓",
            text = "Feelings come and go like clouds in a windy sky. Conscious breathing is my anchor.",
            author = "Thich Nhat Hanh",
        ),
        BlockQuote(
            emoji = "🧘",
            text = "Peace is the result of retraining your mind to process life as it is, rather than as you think it should be.",
            author = "Wayne W. Dyer",
        ),
        BlockQuote(
            emoji = "🌿",
            text = "Nature does not hurry, yet everything is accomplished.",
            author = "Lao Tzu",
        ),
        BlockQuote(
            emoji = "🎈",
            text = "Rule number one is, don't sweat the small stuff. Rule number two is, it's all small stuff.",
            author = "Robert Eliot",
        ),
        BlockQuote(
            emoji = "🏛️",
            text = "You have power over your mind - not outside events. Realize this, and you will find strength.",
            author = "Marcus Aurelius",
        ),
        BlockQuote(
            emoji = "🌊",
            text = "Within you, there is a stillness and a sanctuary to which you can retreat at any time and be yourself.",
            author = "Hermann Hesse",
        ),
        BlockQuote(
            emoji = "🌅",
            text = "The best thing about the future is that it comes one day at a time.",
            author = "Abraham Lincoln",
        ),
        BlockQuote(
            emoji = "🐌",
            text = "Slow down and everything you are chasing will come around and catch you.",
            author = "John De Paula",
        ),
        BlockQuote(
            emoji = "✨",
            text = "Breathe. Let go. And remind yourself that this very moment is the only one you know you have for sure.",
            author = "Oprah Winfrey",
        ),
    )

    private val brightBackgroundColors = intArrayOf(
        0xFF1E88E5.toInt(), // blue
        0xFFE91E63.toInt(), // pink
        0xFF9C27B0.toInt(), // purple
        0xFF00BCD4.toInt(), // cyan
        0xFF4CAF50.toInt(), // green
        0xFFFF9800.toInt(), // orange
        0xFFF44336.toInt(), // red
        0xFF3F51B5.toInt(), // indigo
        0xFF009688.toInt(), // teal
        0xFFFF5722.toInt(), // deep orange
    )

    fun randomQuote(): BlockQuote = quotes[Random.nextInt(quotes.size)]

    fun randomBackgroundColor(): Int =
        brightBackgroundColors[Random.nextInt(brightBackgroundColors.size)]
}
