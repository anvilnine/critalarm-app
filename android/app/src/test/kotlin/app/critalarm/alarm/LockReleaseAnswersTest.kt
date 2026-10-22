package app.critalarm.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LockReleaseAnswersTest {
    @Test
    fun nothingIsAnsweredBeforeTheUnlockPromptAnswers() {
        val answers = LockReleaseAnswers()
        var answered = 0
        answers.add { answered++ }
        assertEquals(0, answered)
        answers.answerAll()
        assertEquals(1, answered)
    }

    @Test
    fun everyReleaseThatWaitedIsAnsweredOnce() {
        val answers = LockReleaseAnswers()
        val answered = mutableListOf<String>()
        answers.add { answered += "acked" }
        answers.add { answered += "left" }
        answers.answerAll()
        answers.answerAll()
        assertEquals(listOf("acked", "left"), answered)
        assertTrue(answers.isEmpty)
    }

    @Test
    fun anAnswerAddedWhileAnsweringWaitsForTheNextCall() {
        val answers = LockReleaseAnswers()
        var late = 0
        answers.add { answers.add { late++ } }
        answers.answerAll()
        assertEquals(0, late)
        answers.answerAll()
        assertEquals(1, late)
    }
}
