#!/bin/sh
exec scala "$0" "$@"
!#

import java.io.File
import scala.language.postfixOps

import scala.xml._

object FindDuplicateStrings {
    def exitWithError(exitCode:Int, errorMessage:String):Unit = {
        println(s"Error($exitCode): $errorMessage")
        sys.exit(exitCode)
    }

    def main(args: Array[String]) = try {
        val projectDirectory = getDirectoryArgument(args)

        // Try to find original strings.xml in 'values' folder
        val stringsXmlFile = findOriginalStringsXmlFile(projectDirectory)

        //Try to find localized strings.xml in 'values-*' folders
        val localizedStringsFiles = findLocalisedStringsXmlFiles(projectDirectory)
        val localizedFileNames = localizedStringsFiles.map(fileNameEntry).mkString(" - ", "\n - ", "\n")

        println(s"""
                   |Found localized files:
                   |$localizedFileNames
                   |
                   | Total: ${localizedStringsFiles.size}
                   |
                 """.stripMargin)


        val originalResources = XmlResources(stringsXmlFile)

        def createDiff(file:File) = file -> XmlResources(file) ~&~ originalResources

        val diffs = for {
            fileDiff <- localizedStringsFiles map createDiff
            if !isEmptyDiff(fileDiff._2)
        } yield fileDiff

        if (diffs.isEmpty) {
            println("No diff! Your strings are in good shape! Keep it up!")
        } else for {
            (file, diff) <- diffs
        } println(
            s"""===============================================
               |Found strings mismatch in: ${niceName(file)}
               |
               |${diffToString(diff)}
               |===============================================""".stripMargin)
        sys.exit(0)
    } catch {
        case e:IllegalArgumentException => exitWithError(1, e.getMessage)
        case e:IllegalStateException => exitWithError(2, e.getMessage)
        case e:Throwable => exitWithError(255, "Unknown error: " + e.toString)
    }

    def isEmptyDiff(diff: (ResourcesDiff, ResourcesDiff)):Boolean = diff match {
        case (left:ResourcesDiff, right: ResourcesDiff) => left.isEmpty && right.isEmpty
        case _ => false
    }

    def diffToString(diff: (ResourcesDiff, ResourcesDiff)):String = {
        val diffMap = Map("NOT LOCALIZED" -> diff._1, "OBSOLETE" -> diff._2)
        val prettyDiffs = for {
            (key, value) <- diffMap
            if value.nonEmpty
        } yield prettyDiff(key, value)
        prettyDiffs.mkString("\n")
    }

    def prettyDiff(title: String, diff: ResourcesDiff):String = if(diff.nonEmpty) {
        s"""$title
           |$diff
         """.stripMargin
    } else { "" }

    def getDirectoryArgument(args: Array[String]):File = if (args.length > 0) {
        val directory = new File(args(0))
        if (directory.exists) {
            directory
        } else {
            throw new IllegalArgumentException(s"Directory [${directory.getAbsolutePath}}] does not exists...")
        }
    } else {
        throw new IllegalArgumentException("Illegal number of arguments. Directory argument should be given...")
    }


    def findOriginalStringsXmlFile(root: File) = {
        val stringsXmlFiles = findStringsXmlFiles(root, originalOnly = true)
        if (stringsXmlFiles.isEmpty) {
            throw new IllegalStateException(s"${root.getAbsolutePath}/res/values/strings.xml not found")
        } else {
            stringsXmlFiles.head
        }
    }

    def findLocalisedStringsXmlFiles(root: File) = {
        val stringsXmlFiles = findStringsXmlFiles(root, originalOnly = false)
        if (stringsXmlFiles.isEmpty) {
            throw new IllegalStateException(s"${root.getAbsolutePath}/res/values-*/strings.xml not found")
        } else {
            stringsXmlFiles
        }
    }

    def findStringsXmlFiles(root: File, originalOnly: Boolean): Array[File] = {
        val valuesDirectoryRegex = if (originalOnly) "values$" else "values."

        val resDirectory = root.listFiles.withFilter(_.getName == "resources")
        val valuesDirectories = resDirectory.flatMap(_.listFiles
                    .filter(f => valuesDirectoryRegex.r.findFirstIn(f.getName).isDefined))
        valuesDirectories.flatMap(_.listFiles.filter(_.getName == "strings.xml"))
    }


    def niceName(f: File) = s"${f.getParentFile.getName}/${f.getName}"
    def fileNameEntry(file:File) = s" - ${niceName(file)}"


    trait Resources {
        def strings:Set[String]
        def stringArrays:Set[String]
        def plurals:Set[String]

        def &~ (other: Resources) = diff(other)
        def diff(other: Resources) = ResourcesDiff(this, other)
        def ~& (other: Resources) = reverseDiff(other)
        def reverseDiff(other: Resources) = ResourcesDiff(other, this)
        def ~&~ (other: Resources) = (reverseDiff(other), diff(other))

        def toMap = Map(
            "strings" -> strings,
            "string-arrays" -> stringArrays,
            "plurals" -> plurals
        )

        private def prettyString(prefix: String, ids:Set[String]) = if (ids.nonEmpty) {
            val sep = s"\n$prefix"
            ids.mkString(sep, sep, "\n")
        }

        private def prettyStringsSet(name: String, ids: Set[String]) = if (ids.nonEmpty) {
            s"$name: ${prettyString("    - ", ids)}"
        } else { "" }

        override def toString = {
            val strings = for {
                (key, value) <- toMap
                if value.nonEmpty
            } yield prettyStringsSet(key, value)
            strings.mkString("\n")
        }
    }

    case class ResourcesDiff(original: Resources, compared: Resources) extends Resources {
        override lazy val strings = original.strings &~ compared.strings
        override lazy val stringArrays = original.stringArrays &~ compared.stringArrays
        override lazy val plurals = original.plurals &~ compared.plurals

        def nonEmpty = !isEmpty
        def isEmpty = strings.isEmpty && stringArrays.isEmpty && plurals.isEmpty
    }

    case class XmlResources(stringsXmlFile: File) extends Resources {
        lazy val resources = XML.loadFile(stringsXmlFile) \\ "resources"

        override lazy val strings = namesSet("string")
        override lazy val stringArrays = namesSet("string-array")
        override lazy val plurals = namesSet("plurals")

        private def names(tag: String) = (resources \ tag) map (_ \ "@name" text)
        private def namesSet(tag: String) = names(tag).toSet
    }
}
