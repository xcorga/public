import java.io.File
import java.nio.file.Files
import java.nio.file.Path
import java.util.Properties
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
        val source: Path,
        val target: Path,
    )

    fun doMapping(rootProjectDir: File) {
        // 从local.properties读取config.dir属性，或者通过CONFIG_DIR_DEFAULT环境变量，来决定使用哪个配置目录
        val configDir = rootProjectDir.resolve("local.properties")
            .takeIf { it.exists() }
            ?.let { loadProperties(it) }
            ?.getProperty("config.dir")
            ?: System.getenv("APP_CONFIG_DIR")
            ?: throw IllegalArgumentException("Please configure the config.dir property in local.properties or configure the APP_CONFIG_DIR environment variable!")

        println("Reading config.dir from local.properties: $configDir")

        // 从file-mapping.txt读取文件映射关系
        val mappingList = readMappingFile(
            file = rootProjectDir.resolve("file-mapping.txt"),
            sourceDir = rootProjectDir.resolve(configDir),
            targetDir = rootProjectDir
        )

        // 映射后的路径写入.gitignore
        modifyGitIgnoreFile(
            file = rootProjectDir.resolve(".gitignore"),
            newContent = mappingList.map { it.target.toFile().toRelativeString(rootProjectDir) }
        )

        // 开始映射
        mappingList.forEach(::updateSymbolicLink)
    }

    private fun loadProperties(file: File): Properties {
        if (!file.exists()) {
            throw RuntimeException("The specified properties file does not exist: ${file.absolutePath}")
        }
        return Properties().apply {
            file.inputStream().use { load(it) }
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

FileMappingHelper.doMapping(rootProjectDir = projectDir)