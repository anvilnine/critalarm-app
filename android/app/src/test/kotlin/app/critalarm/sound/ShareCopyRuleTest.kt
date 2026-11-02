package app.critalarm.sound

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.file.Files

/**
 * Which pending_audio_path MainActivity hands to Dart. Dart deletes what it
 * is handed, so a path from outside the share folder must never get through.
 * The same cases as test/core/sound/share_copy_path_test.dart.
 */
class ShareCopyRuleTest {
    @get:Rule
    val temp = TemporaryFolder()

    private lateinit var cache: File
    private lateinit var folder: File
    private lateinit var prefs: File

    @Before
    fun setUp() {
        cache = temp.newFolder("cache")
        folder = File(cache, ShareReceiverActivity.FOLDER).apply { mkdirs() }
        prefs = temp.newFolder("shared_prefs").resolve("critalarm.xml").apply { writeText("x") }
    }

    @Test
    fun aCopyInsideTheFolderThatWasIssuedGetsThrough() {
        val copy = File(folder, "1234_memo.m4a").apply { writeText("audio") }
        assertTrue(ShareCopyRule.accepts(copy.path, folder, issued = true))
    }

    @Test
    fun aPathNobodyIssuedIsDroppedEvenInsideTheFolder() {
        val copy = File(folder, "1234_memo.m4a").apply { writeText("audio") }
        assertFalse(ShareCopyRule.accepts(copy.path, folder, issued = false))
    }

    @Test
    fun aFileOutsideTheFolderIsDropped() {
        assertFalse(ShareCopyRule.isInside(prefs.path, folder))
    }

    @Test
    fun dotDotIsDroppedWhereverItLeads() {
        assertFalse(ShareCopyRule.isInside("${folder.path}/../../shared_prefs/critalarm.xml", folder))
        // Back into the same folder is still turned away.
        File(folder, "a.m4a").writeText("audio")
        assertFalse(ShareCopyRule.isInside("${folder.path}/../${folder.name}/a.m4a", folder))
        assertFalse(ShareCopyRule.isInside("${folder.path}/./a.m4a", folder))
    }

    @Test
    fun aLinkInsideTheFolderThatPointsOutIsDropped() {
        val link = File(folder, "1234_memo.m4a")
        Files.createSymbolicLink(link.toPath(), prefs.toPath())
        assertFalse(ShareCopyRule.isInside(link.path, folder))
        assertTrue(prefs.exists())
    }

    @Test
    fun aFileInAFolderBelowTheShareFolderIsDropped() {
        val nested = File(folder, "deeper").apply { mkdirs() }
        val copy = File(nested, "a.m4a").apply { writeText("audio") }
        assertFalse(ShareCopyRule.isInside(copy.path, folder))
    }

    @Test
    fun theFolderItselfAndRelativePathsAreDropped() {
        assertFalse(ShareCopyRule.isInside(folder.path, folder))
        assertFalse(ShareCopyRule.isInside("incoming_audio/a.m4a", folder))
    }

    @Test
    fun aCopyThatWasNeverWrittenStillGetsThrough() {
        // A file over the size cap is never copied. Dart still needs the path
        // to say the file is too large.
        assertTrue(ShareCopyRule.isInside(File(folder, "1234_huge.wav").path, folder))
    }
}
