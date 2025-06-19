import java.nio.file.Files
import java.util.Properties
import kotlin.apply
import kotlin.io.path.exists
import kotlin.io.path.isSymbolicLink
import kotlin.io.path.notExists

private object FileMappingHelper {

    const val AUTO_GENERATED_BEGIN = "# === AUTO-GENERATED: DO NOT EDIT ==="

    const val AUTO_GENERATED_END = "# === END AUTO-GENERATED ==="

    val AUTO_GENERATED_REGEX = buildString {
        append("(${AUTO_GENERATED_BEGIN.replace(Regex("\\s+"), "\\\\s+")})")
        append("(.*?)")
        append("(${AUTO_GENERATED_END.replace(Regex("\\s+"), "\\\\s+")})")
    }.toRegex(setOf(RegexOption.MULTILINE, RegexOption.DOT_MATCHES_ALL))

    data class Mapping(
        val source: java.nio.file.Path,
        val target: java.nio.file.Path,
    )

    fun doMapping(rootProject: Project) {
        // 按照以下优先级来决定使用哪个配置目录
        val configDir = rootProject.findProperty("APP_CONFIG_DIR") as? String // Gradle -P参数
            ?: loadPropertiesOrNull(rootProject.file("local.properties"))?.getProperty("config.dir") // 从local.properties读取config.dir属性
            ?: System.getenv("APP_CONFIG_DIR") // 环境变量
            ?: throw IllegalArgumentException("Please configure the config.dir property in local.properties or configure the APP_CONFIG_DIR environment variable!")

        println("Reading config.dir from local.properties: $configDir")

        // 从file-mapping.txt读取文件映射关系
        val mappingList = readMappingFile(
            file = rootProject.file("file-mapping.txt"),
            sourceDir = rootProject.file(configDir),
            targetDir = rootProject.projectDir
        )

        // 映射后的路径写入.gitignore
        modifyGitIgnoreFile(
            file = rootProject.file(".gitignore"),
            newContent = mappingList.map { it.target.toFile().toRelativeString(rootProject.projectDir) }
        )

        // 开始映射
        mappingList.forEach(::updateSymbolicLink)
    }

    private fun loadPropertiesOrNull(file: File): Properties? {
        return if (file.exists()) {
            Properties().apply {
                file.inputStream().use { load(it) }
            }
        } else {
            null
        }
    }

    private fun readMappingFile(file: File, sourceDir: File, targetDir: File): List<Mapping> {
        return file.useLines { lines ->
            lines.mapIndexed { index, line ->
                val split = line.splitToSequence("->")
                    .map { it.trim() }
                    .filter { it.isNotBlank() }
                    .toList()
                if (split.size != 2) {
                    throw IllegalArgumentException("Error in line ${index + 1}: '$line' is not in the correct 'key->value' format.")
                }
                val source = sourceDir.resolve(split[0]).toPath()
                val target = targetDir.resolve(split[1]).toPath()
                if (source.notExists()) {
                    throw IllegalArgumentException("Source file does not exist: ${source.toAbsolutePath()}")
                }
                Mapping(source = source, target = target)
            }.toList()
        }
    }

    private fun modifyGitIgnoreFile(file: File, newContent: List<String>) {
        val text = file.readText()
        // 替换 AUTO_GENERATE 之间的内容
        if (text.contains(AUTO_GENERATED_REGEX)) {
            val newText = text.replace(AUTO_GENERATED_REGEX) { matchResult ->
                buildString {
                    appendLine(matchResult.groupValues[1])
                    newContent.forEach { line ->
                        appendLine(line)
                    }
                    append(matchResult.groupValues[3])
                }
            }
            if (text != newText) {
                file.writeText(newText)
                println("Updating mapping rules in the .gitignore file")
            } else {
                println("Skipping update mapping rules in the .gitignore file")
            }
        } else {
            val newText = buildString {
                if (!text.endsWith("\n")) {
                    appendLine()
                }
                appendLine(AUTO_GENERATED_BEGIN)
                newContent.forEach { line ->
                    appendLine(line)
                }
                append(AUTO_GENERATED_END)
            }
            file.appendText(newText)
            println("Add mapping rules to the .gitignore file")
        }
    }

    private fun updateSymbolicLink(mapping: Mapping) {
        val target = mapping.target
        val source = mapping.source

        if (target.exists()) {
            if (target.isSymbolicLink()) {
                // 检查符号链接是否指向正确的源
                val currentTarget = Files.readSymbolicLink(target)
                if (currentTarget != source) {
                    println("(Updating) Mapping file: $source -> $target")
                    Files.delete(target)  // 删除现有符号链接
                    Files.createSymbolicLink(target, source)  // 创建新的符号链接
                } else {
                    println("(Skipping) Mapping file: $source -> $target")
                }
            } else {
                throw RuntimeException("Target is not a symbolic link: $target")
            }
        } else {
            // 确保符号链接的父目录存在
            Files.createDirectories(target.parent)
            // 符号链接存在但是指向的文件不存在，需要先删除原来的链接
            Files.deleteIfExists(target)
            // 创建符号链接
            Files.createSymbolicLink(target, source)
            println("Mapping file: $source -> $target")
        }
    }
}

FileMappingHelper.doMapping(rootProject = project)