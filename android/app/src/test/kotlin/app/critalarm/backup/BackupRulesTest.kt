package app.critalarm.backup

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

/**
 * Nothing this app keeps is in a backup or a phone to phone transfer.
 *
 * The preferences hold this phone's device id and device token, and the
 * files folder holds the person's own alarm photo and own sounds. A restore
 * of either onto another phone is the bug, so every domain is left out in
 * every list, and the manifest points at both files.
 *
 * This reads the files. What a restore really brings back is proved on an
 * emulator with `adb shell bmgr`, not here.
 */
class BackupRulesTest {
    private val domains = setOf(
        "root",
        "file",
        "database",
        "sharedpref",
        "external",
        "device_root",
        "device_file",
        "device_database",
        "device_sharedpref",
    )

    private fun parse(path: String): Element =
        DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(File(path)).documentElement

    private fun children(parent: Element, name: String): List<Element> {
        val found = mutableListOf<Element>()
        val nodes = parent.childNodes
        for (index in 0 until nodes.length) {
            val node = nodes.item(index)
            if (node is Element && node.tagName == name) found.add(node)
        }
        return found
    }

    /** The domains [section] leaves out whole, and nothing it lets in. */
    private fun assertLeavesEverythingOut(section: Element, label: String) {
        assertTrue("$label lets something in", children(section, "include").isEmpty())
        val excludes = children(section, "exclude")
        for (exclude in excludes) {
            assertEquals("$label: a whole domain", ".", exclude.getAttribute("path"))
        }
        assertEquals(label, domains, excludes.map { it.getAttribute("domain") }.toSet())
    }

    @Test
    fun `the cloud backup leaves every domain out`() {
        val root = parse("src/main/res/xml/data_extraction_rules.xml")
        assertEquals("data-extraction-rules", root.tagName)
        val sections = children(root, "cloud-backup")
        assertEquals(1, sections.size)
        assertLeavesEverythingOut(sections.single(), "cloud-backup")
    }

    @Test
    fun `a phone to phone transfer leaves every domain out`() {
        val root = parse("src/main/res/xml/data_extraction_rules.xml")
        val sections = children(root, "device-transfer")
        assertEquals(1, sections.size)
        assertLeavesEverythingOut(sections.single(), "device-transfer")
    }

    @Test
    fun `the rules for Android 11 and earlier leave every domain out`() {
        val root = parse("src/main/res/xml/backup_rules.xml")
        assertEquals("full-backup-content", root.tagName)
        assertLeavesEverythingOut(root, "full-backup-content")
    }

    @Test
    fun `the manifest turns backup off and names both files`() {
        val application = children(parse("src/main/AndroidManifest.xml"), "application").single()
        assertEquals("false", application.getAttribute("android:allowBackup"))
        assertEquals(
            "@xml/data_extraction_rules",
            application.getAttribute("android:dataExtractionRules"),
        )
        assertEquals("@xml/backup_rules", application.getAttribute("android:fullBackupContent"))
    }
}
